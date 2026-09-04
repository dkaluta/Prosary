package com.dkaluta.prosary.content.prayerpack

import android.content.res.AssetManager
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.channels.FileChannel
import java.nio.charset.CodingErrorAction
import java.util.zip.CRC32
import java.util.zip.DataFormatException
import java.util.zip.Inflater

/** A small ZIP reader for the access pattern prayer packs need: index the central directory once,
 * then seek directly to a requested member. `ZipInputStream` has no random access and therefore
 * inflates every earlier DEFLATE member while skipping toward a later image or audio file.
 *
 * This reader intentionally implements only ordinary single-disk ZIP archives. A prayer-pack
 * entry is bounded to the portable 32-bit format even when it is streamed, so ZIP64 and multi-
 * disk inputs cannot be useful to the app and are rejected before trusting untrusted fields. */
internal class SeekableZipArchive private constructor(
    private val source: SeekableZipSource,
    private val entriesByName: LinkedHashMap<String, Entry>,
    private val centralDirectoryOffset: Long,
) {
    val entryNames: List<String> = entriesByName.keys.toList()

    /** Stable identity from the ZIP directory, without opening or inflating the entry. */
    fun entryFingerprint(name: String): String? = entriesByName[name]?.let { entry ->
        "%08x-%d".format(java.util.Locale.ROOT, entry.crc, entry.uncompressedSize)
    }

    /** Opens an owned descriptor/channel for one member. The caller closes it with `use`; this
     * allows the store to acquire the descriptor while its source lock is held, then release the
     * lock before any file I/O or inflation. An already-open Unix descriptor remains bound to the
     * original file even if an installed pack is removed or replaced at the same pathname. */
    fun openEntry(name: String, maxBytes: Long = DEFAULT_MAX_ENTRY_BYTES): EntryReader? {
        val entry = entriesByName[name] ?: return null
        val handle = source.open()
        return object : EntryReader {
            override fun read(): ByteArray = readEntry(
                channel = handle.channel,
                baseOffset = handle.baseOffset,
                archiveLength = handle.length,
                dataLimit = centralDirectoryOffset,
                entry = entry,
                maxBytes = maxBytes,
            )

            override fun copyTo(output: OutputStream) = copyEntry(
                channel = handle.channel,
                baseOffset = handle.baseOffset,
                archiveLength = handle.length,
                dataLimit = centralDirectoryOffset,
                entry = entry,
                maxBytes = maxBytes,
                output = output,
            )

            override fun close() = handle.close()
        }
    }

    fun read(name: String, maxBytes: Long = DEFAULT_MAX_ENTRY_BYTES): ByteArray? =
        openEntry(name, maxBytes)?.use { it.read() }

    /** Reads several independently addressed members while sharing one descriptor/channel and
     * enforcing limits before any untrusted output-sized allocation. */
    fun read(
        names: Collection<String>,
        maxEntryBytes: Long = DEFAULT_MAX_ENTRY_BYTES,
        maxTotalBytes: Long = DEFAULT_MAX_ENTRY_BYTES,
    ): Map<String, ByteArray> {
        val selected = names.mapNotNull { name -> entriesByName[name]?.let { name to it } }
        var totalSize = 0L
        for ((_, entry) in selected) {
            if (entry.uncompressedSize > maxEntryBytes || entry.compressedSize > maxEntryBytes) {
                throw IOException("Prayer-pack entry is too large")
            }
            if (entry.uncompressedSize > maxTotalBytes - totalSize) {
                throw IOException("Prayer-pack metadata is too large")
            }
            totalSize += entry.uncompressedSize
        }
        return source.open().use { handle ->
            buildMap {
                for ((name, entry) in selected) {
                    put(
                        name,
                        readEntry(
                            channel = handle.channel,
                            baseOffset = handle.baseOffset,
                            archiveLength = handle.length,
                            dataLimit = centralDirectoryOffset,
                            entry = entry,
                            maxBytes = maxEntryBytes,
                        ),
                    )
                }
            }
        }
    }

    interface EntryReader : java.io.Closeable {
        fun read(): ByteArray

        /** Compatibility sources may still use the bounded byte-array read. Indexed production
         * sources override this with fixed-buffer stored/DEFLATE streaming. */
        fun copyTo(output: OutputStream) {
            output.write(read())
        }
    }

    companion object {
        private const val EOCD_SIGNATURE = 0x06054b50L
        private const val CENTRAL_HEADER_SIGNATURE = 0x02014b50L
        private const val LOCAL_HEADER_SIGNATURE = 0x04034b50L
        private const val EOCD_SIZE = 22
        private const val MAX_ZIP_COMMENT = 65_535
        private const val CENTRAL_HEADER_SIZE = 46
        private const val LOCAL_HEADER_SIZE = 30
        private const val STORED = 0
        private const val DEFLATED = 8
        private const val ZIP64_U16 = 0xffff
        private const val ZIP64_U32 = 0xffff_ffffL
        private const val MAX_CENTRAL_DIRECTORY_BYTES = 16L * 1024L * 1024L
        private const val MAX_ENTRY_COUNT = 4_096
        const val DEFAULT_MAX_ENTRY_BYTES = 256L * 1024L * 1024L
        const val MAX_EXPANDED_BYTES = 512L * 1024L * 1024L
        const val MAX_ARCHIVE_BYTES = 576L * 1024L * 1024L

        fun fromFile(file: File): SeekableZipArchive = open(FileZipSource(file))

        fun fromAsset(assets: AssetManager, assetName: String): SeekableZipArchive =
            open(AssetZipSource(assets, assetName))

        private fun open(source: SeekableZipSource): SeekableZipArchive {
            val directory = source.open().use { handle ->
                if (handle.length > MAX_ARCHIVE_BYTES) {
                    throw IOException("Prayer-pack archive is too large")
                }
                readCentralDirectory(handle.channel, handle.baseOffset, handle.length)
            }
            return SeekableZipArchive(source, directory.entries, directory.offset)
        }

        private fun readCentralDirectory(
            channel: FileChannel,
            baseOffset: Long,
            archiveLength: Long,
        ): CentralDirectory {
            if (archiveLength < EOCD_SIZE) throw IOException("ZIP is shorter than its end record")
            val tailLength = minOf(archiveLength, (EOCD_SIZE + MAX_ZIP_COMMENT).toLong()).toInt()
            val tailStart = archiveLength - tailLength
            val tail = readExactly(channel, baseOffset + tailStart, tailLength)
            val eocdOffset = (tail.size - EOCD_SIZE downTo 0).firstOrNull { offset ->
                tail.u32(offset) == EOCD_SIGNATURE &&
                    offset + EOCD_SIZE + tail.u16(offset + 20) == tail.size
            } ?: throw IOException("ZIP end record is missing")

            val diskNumber = tail.u16(eocdOffset + 4)
            val centralDisk = tail.u16(eocdOffset + 6)
            val entriesOnDisk = tail.u16(eocdOffset + 8)
            val entryCount = tail.u16(eocdOffset + 10)
            val centralSize = tail.u32(eocdOffset + 12)
            val centralOffset = tail.u32(eocdOffset + 16)
            if (
                diskNumber != 0 || centralDisk != 0 || entriesOnDisk != entryCount ||
                entryCount == ZIP64_U16 || centralSize == ZIP64_U32 || centralOffset == ZIP64_U32
            ) {
                throw IOException("Multi-disk and ZIP64 prayer packs are unsupported")
            }
            if (entryCount > MAX_ENTRY_COUNT || centralSize > MAX_CENTRAL_DIRECTORY_BYTES) {
                throw IOException("Prayer-pack ZIP directory is too large")
            }
            val eocdStart = tailStart + eocdOffset
            requireArchiveRange(centralOffset, centralSize, eocdStart)
            if (centralOffset + centralSize != eocdStart) {
                throw IOException("ZIP central directory does not end at its end record")
            }

            val result = linkedMapOf<String, Entry>()
            val seenNames = mutableSetOf<String>()
            val occupiedRanges = mutableListOf<LongRange>()
            var cursor = centralOffset
            var totalUncompressed = 0L
            repeat(entryCount) {
                requireArchiveRange(cursor, CENTRAL_HEADER_SIZE.toLong(), centralOffset + centralSize)
                val header = readExactly(channel, baseOffset + cursor, CENTRAL_HEADER_SIZE)
                if (header.u32(0) != CENTRAL_HEADER_SIGNATURE) {
                    throw IOException("Invalid ZIP central-directory entry")
                }
                val flags = header.u16(8)
                val method = header.u16(10)
                val crc = header.u32(16)
                val compressedSize = header.u32(20)
                val uncompressedSize = header.u32(24)
                val nameLength = header.u16(28)
                val extraLength = header.u16(30)
                val commentLength = header.u16(32)
                val startDisk = header.u16(34)
                val localHeaderOffset = header.u32(42)
                if (
                    startDisk != 0 || compressedSize == ZIP64_U32 ||
                    uncompressedSize == ZIP64_U32 || localHeaderOffset == ZIP64_U32
                ) {
                    throw IOException("Multi-disk and ZIP64 prayer-pack entries are unsupported")
                }
                if (method != STORED && method != DEFLATED) {
                    throw IOException("Unsupported ZIP compression method $method")
                }
                val allowedFlags = 0x0800 or 0x0008 or if (method == DEFLATED) 0x0006 else 0
                if (flags and allowedFlags.inv() != 0) {
                    throw IOException("Unsupported ZIP entry flags")
                }
                if (method == STORED && compressedSize != uncompressedSize) {
                    throw IOException("Stored ZIP entry has inconsistent sizes")
                }
                if (
                    compressedSize > DEFAULT_MAX_ENTRY_BYTES ||
                    uncompressedSize > DEFAULT_MAX_ENTRY_BYTES
                ) {
                    throw IOException("Prayer-pack entry is too large")
                }
                if (uncompressedSize > MAX_EXPANDED_BYTES - totalUncompressed) {
                    throw IOException("Expanded prayer pack is too large")
                }
                totalUncompressed += uncompressedSize
                val recordSize = CENTRAL_HEADER_SIZE.toLong() + nameLength + extraLength + commentLength
                requireArchiveRange(cursor, recordSize, centralOffset + centralSize)
                val nameBytes = readExactly(
                    channel,
                    baseOffset + cursor + CENTRAL_HEADER_SIZE,
                    nameLength,
                )
                val name = runCatching {
                    Charsets.UTF_8.newDecoder()
                        .onMalformedInput(CodingErrorAction.REPORT)
                        .onUnmappableCharacter(CodingErrorAction.REPORT)
                        .decode(ByteBuffer.wrap(nameBytes))
                        .toString()
                }.getOrElse { throw IOException("ZIP entry name is not valid UTF-8", it) }
                if (!isSafeEntryName(name) || !seenNames.add(name)) {
                    throw IOException("ZIP contains an invalid or duplicate entry name")
                }
                val entry = Entry(
                    nameBytes = nameBytes,
                    flags = flags,
                    method = method,
                    crc = crc,
                    compressedSize = compressedSize,
                    uncompressedSize = uncompressedSize,
                    localHeaderOffset = localHeaderOffset,
                )
                val local = validateLocalRecord(
                    channel = channel,
                    baseOffset = baseOffset,
                    archiveLength = archiveLength,
                    dataLimit = centralOffset,
                    entry = entry,
                )
                occupiedRanges += entry.localHeaderOffset until local.recordEnd
                if (name.endsWith('/')) {
                    if (compressedSize != 0L || uncompressedSize != 0L) {
                        throw IOException("ZIP directory entry contains a payload")
                    }
                } else {
                    result[name] = entry
                }
                cursor += recordSize
            }
            if (cursor != centralOffset + centralSize) {
                throw IOException("ZIP central-directory size disagrees with its entries")
            }
            occupiedRanges.sortBy { it.first }
            for (index in 1 until occupiedRanges.size) {
                if (occupiedRanges[index].first < occupiedRanges[index - 1].last + 1) {
                    throw IOException("ZIP local records overlap")
                }
            }
            return CentralDirectory(result, centralOffset)
        }

        private fun isSafeEntryName(name: String): Boolean {
            if (name.isEmpty() || name.startsWith('/') || '\\' in name || '\u0000' in name) {
                return false
            }
            val path = name.removeSuffix("/")
            return path.isNotEmpty() && path.split('/').none { part ->
                part.isEmpty() || part == "." || part == ".."
            }
        }

        private fun validateLocalRecord(
            channel: FileChannel,
            baseOffset: Long,
            archiveLength: Long,
            dataLimit: Long,
            entry: Entry,
        ): LocalRecord {
            requireArchiveRange(entry.localHeaderOffset, LOCAL_HEADER_SIZE.toLong(), dataLimit)
            val localHeader = readExactly(
                channel,
                baseOffset + entry.localHeaderOffset,
                LOCAL_HEADER_SIZE,
            )
            if (localHeader.u32(0) != LOCAL_HEADER_SIGNATURE) {
                throw IOException("Invalid ZIP local-file header")
            }
            if (localHeader.u16(6) != entry.flags || localHeader.u16(8) != entry.method) {
                throw IOException("ZIP local and central headers disagree")
            }
            val localCrc = localHeader.u32(14)
            val localCompressedSize = localHeader.u32(18)
            val localUncompressedSize = localHeader.u32(22)
            val nameLength = localHeader.u16(26)
            val extraLength = localHeader.u16(28)
            requireArchiveRange(
                entry.localHeaderOffset + LOCAL_HEADER_SIZE,
                (nameLength + extraLength).toLong(),
                dataLimit,
            )
            val localName = readExactly(
                channel,
                baseOffset + entry.localHeaderOffset + LOCAL_HEADER_SIZE,
                nameLength,
            )
            if (!localName.contentEquals(entry.nameBytes)) {
                throw IOException("ZIP local and central entry names disagree")
            }

            val usesDescriptor = entry.flags and 0x0008 != 0
            val localValuesAreEmpty =
                localCrc == 0L && localCompressedSize == 0L && localUncompressedSize == 0L
            val localValuesMatch =
                localCrc == entry.crc && localCompressedSize == entry.compressedSize &&
                    localUncompressedSize == entry.uncompressedSize
            if (if (usesDescriptor) !localValuesAreEmpty && !localValuesMatch else !localValuesMatch) {
                throw IOException("ZIP local and central sizes disagree")
            }

            val dataOffset = entry.localHeaderOffset + LOCAL_HEADER_SIZE + nameLength + extraLength
            requireArchiveRange(dataOffset, entry.compressedSize, dataLimit)
            requireArchiveRange(dataOffset, entry.compressedSize, archiveLength)
            var recordEnd = dataOffset + entry.compressedSize
            if (usesDescriptor) {
                recordEnd = validateDescriptor(
                    channel,
                    baseOffset,
                    recordEnd,
                    dataLimit,
                    entry,
                )
            }
            return LocalRecord(dataOffset, recordEnd)
        }

        private fun validateDescriptor(
            channel: FileChannel,
            baseOffset: Long,
            offset: Long,
            dataLimit: Long,
            entry: Entry,
        ): Long {
            fun matches(start: Long): Boolean {
                if (start < 0 || start > dataLimit - 12) return false
                val descriptor = readExactly(channel, baseOffset + start, 12)
                return descriptor.u32(0) == entry.crc &&
                    descriptor.u32(4) == entry.compressedSize &&
                    descriptor.u32(8) == entry.uncompressedSize
            }

            if (offset >= 0 && offset <= dataLimit - 16) {
                val signature = readExactly(channel, baseOffset + offset, 4).u32(0)
                if (signature == 0x08074b50L && matches(offset + 4)) return offset + 16
            }
            if (matches(offset)) return offset + 12
            throw IOException("ZIP data descriptor disagrees with its central header")
        }

        private fun readEntry(
            channel: FileChannel,
            baseOffset: Long,
            archiveLength: Long,
            dataLimit: Long,
            entry: Entry,
            maxBytes: Long,
        ): ByteArray {
            val compressed = openValidatedEntry(
                channel,
                baseOffset,
                archiveLength,
                dataLimit,
                entry,
                maxBytes,
            )
            val expectedSize = entry.uncompressedSize.toInt()
            val bytes = when (entry.method) {
                STORED -> compressed.readExact(expectedSize)
                DEFLATED -> inflateRaw(compressed, expectedSize)
                else -> throw IOException("Unsupported ZIP compression method ${entry.method}")
            }
            val actualCrc = CRC32().apply { update(bytes) }.value
            if (actualCrc != entry.crc) throw IOException("Prayer-pack entry failed its CRC check")
            return bytes
        }

        private fun copyEntry(
            channel: FileChannel,
            baseOffset: Long,
            archiveLength: Long,
            dataLimit: Long,
            entry: Entry,
            maxBytes: Long,
            output: OutputStream,
        ) {
            val compressed = openValidatedEntry(
                channel,
                baseOffset,
                archiveLength,
                dataLimit,
                entry,
                maxBytes,
            )
            val actualCrc = when (entry.method) {
                STORED -> copyStored(compressed, entry.uncompressedSize.toInt(), output)
                DEFLATED -> inflateRawTo(compressed, entry.uncompressedSize.toInt(), output)
                else -> throw IOException("Unsupported ZIP compression method ${entry.method}")
            }
            if (actualCrc != entry.crc) throw IOException("Prayer-pack entry failed its CRC check")
        }

        private fun openValidatedEntry(
            channel: FileChannel,
            baseOffset: Long,
            archiveLength: Long,
            dataLimit: Long,
            entry: Entry,
            maxBytes: Long,
        ): ChannelRangeInputStream {
            if (entry.uncompressedSize > maxBytes || entry.compressedSize > maxBytes) {
                throw IOException("Prayer-pack entry is too large")
            }
            val local = validateLocalRecord(
                channel,
                baseOffset,
                archiveLength,
                dataLimit,
                entry,
            )

            val compressed = ChannelRangeInputStream(
                channel = channel,
                start = baseOffset + local.dataOffset,
                length = entry.compressedSize,
            )
            return compressed
        }

        private fun copyStored(
            input: ChannelRangeInputStream,
            expectedSize: Int,
            output: OutputStream,
        ): Long {
            val buffer = ByteArray(32 * 1024)
            val checksum = CRC32()
            var written = 0
            while (written < expectedSize) {
                val count = input.read(buffer, 0, minOf(buffer.size, expectedSize - written))
                if (count < 0) throw IOException("ZIP entry ended before its declared size")
                if (count == 0) continue
                output.write(buffer, 0, count)
                checksum.update(buffer, 0, count)
                written += count
            }
            if (input.bytesRemaining != 0L) {
                throw IOException("ZIP entry exceeds its declared uncompressed size")
            }
            return checksum.value
        }

        private fun inflateRaw(input: ChannelRangeInputStream, expectedSize: Int): ByteArray {
            val inflater = Inflater(true)
            val compressedBuffer = ByteArray(32 * 1024)
            val overflow = ByteArray(1)
            val result = ByteArray(expectedSize)
            var outputOffset = 0
            var suppliedDummyByte = false
            try {
                while (!inflater.finished()) {
                    if (inflater.needsInput()) {
                        val count = input.read(compressedBuffer)
                        if (count >= 0) {
                            inflater.setInput(compressedBuffer, 0, count)
                        } else if (!suppliedDummyByte) {
                            // Raw zlib streams require one synthetic byte after the exact ZIP
                            // member on some implementations/bit alignments.
                            inflater.setInput(DUMMY_ZERO)
                            suppliedDummyByte = true
                        } else {
                            throw IOException("ZIP entry ended before DEFLATE finished")
                        }
                    }

                    val remainingOutput = expectedSize - outputOffset
                    val count = if (remainingOutput > 0) {
                        inflater.inflate(result, outputOffset, remainingOutput)
                    } else {
                        inflater.inflate(overflow)
                    }
                    if (count > 0) {
                        if (remainingOutput == 0) {
                            throw IOException("ZIP entry exceeds its declared uncompressed size")
                        }
                        outputOffset += count
                    } else if (inflater.needsDictionary()) {
                        throw IOException("ZIP entry requires a DEFLATE dictionary")
                    } else if (!inflater.needsInput() && !inflater.finished()) {
                        throw IOException("ZIP DEFLATE stream made no progress")
                    }
                }
                if (outputOffset != expectedSize) {
                    throw IOException("ZIP entry ended before its declared size")
                }
                val allowedDummyRemainder = if (suppliedDummyByte) 1 else 0
                if (input.bytesRemaining != 0L || inflater.remaining > allowedDummyRemainder) {
                    throw IOException("ZIP entry contains trailing compressed data")
                }
                return result
            } catch (error: DataFormatException) {
                throw IOException("Invalid raw DEFLATE stream", error)
            } finally {
                inflater.end()
            }
        }

        private fun inflateRawTo(
            input: ChannelRangeInputStream,
            expectedSize: Int,
            output: OutputStream,
        ): Long {
            val inflater = Inflater(true)
            val compressedBuffer = ByteArray(32 * 1024)
            val outputBuffer = ByteArray(32 * 1024)
            val overflow = ByteArray(1)
            val checksum = CRC32()
            var outputSize = 0
            var suppliedDummyByte = false
            try {
                while (!inflater.finished()) {
                    if (inflater.needsInput()) {
                        val count = input.read(compressedBuffer)
                        if (count >= 0) {
                            inflater.setInput(compressedBuffer, 0, count)
                        } else if (!suppliedDummyByte) {
                            inflater.setInput(DUMMY_ZERO)
                            suppliedDummyByte = true
                        } else {
                            throw IOException("ZIP entry ended before DEFLATE finished")
                        }
                    }

                    val remainingOutput = expectedSize - outputSize
                    val count = if (remainingOutput > 0) {
                        inflater.inflate(outputBuffer, 0, minOf(outputBuffer.size, remainingOutput))
                    } else {
                        inflater.inflate(overflow)
                    }
                    if (count > 0) {
                        if (remainingOutput == 0) {
                            throw IOException("ZIP entry exceeds its declared uncompressed size")
                        }
                        output.write(outputBuffer, 0, count)
                        checksum.update(outputBuffer, 0, count)
                        outputSize += count
                    } else if (inflater.needsDictionary()) {
                        throw IOException("ZIP entry requires a DEFLATE dictionary")
                    } else if (!inflater.needsInput() && !inflater.finished()) {
                        throw IOException("ZIP DEFLATE stream made no progress")
                    }
                }
                if (outputSize != expectedSize) {
                    throw IOException("ZIP entry ended before its declared size")
                }
                val allowedDummyRemainder = if (suppliedDummyByte) 1 else 0
                if (input.bytesRemaining != 0L || inflater.remaining > allowedDummyRemainder) {
                    throw IOException("ZIP entry contains trailing compressed data")
                }
                return checksum.value
            } catch (error: DataFormatException) {
                throw IOException("Invalid raw DEFLATE stream", error)
            } finally {
                inflater.end()
            }
        }

        private fun InputStream.readExact(size: Int): ByteArray {
            val result = ByteArray(size)
            var offset = 0
            while (offset < size) {
                val count = read(result, offset, size - offset)
                if (count < 0) throw IOException("ZIP entry ended before its declared size")
                if (count == 0) continue
                offset += count
            }
            return result
        }

        private fun readExactly(channel: FileChannel, position: Long, size: Int): ByteArray {
            val result = ByteArray(size)
            val buffer = ByteBuffer.wrap(result)
            var cursor = position
            while (buffer.hasRemaining()) {
                val count = channel.read(buffer, cursor)
                if (count < 0) throw IOException("ZIP data ended unexpectedly")
                if (count == 0) continue
                cursor += count
            }
            return result
        }

        private fun requireArchiveRange(offset: Long, length: Long, archiveLength: Long) {
            if (offset < 0 || length < 0 || offset > archiveLength - length) {
                throw IOException("ZIP entry points outside the prayer pack")
            }
        }

        private fun ByteArray.u16(offset: Int): Int =
            (this[offset].toInt() and 0xff) or ((this[offset + 1].toInt() and 0xff) shl 8)

        private fun ByteArray.u32(offset: Int): Long =
            (u16(offset).toLong() or (u16(offset + 2).toLong() shl 16)) and 0xffff_ffffL

        private val DUMMY_ZERO = byteArrayOf(0)
    }

    private data class CentralDirectory(
        val entries: LinkedHashMap<String, Entry>,
        val offset: Long,
    )

    private data class LocalRecord(
        val dataOffset: Long,
        val recordEnd: Long,
    )

    private data class Entry(
        val nameBytes: ByteArray,
        val flags: Int,
        val method: Int,
        val crc: Long,
        val compressedSize: Long,
        val uncompressedSize: Long,
        val localHeaderOffset: Long,
    )
}

/** Owns a bounded view of either an uncompressed Android asset or a regular installed file. */
private interface SeekableZipSource {
    fun open(): SeekableZipHandle
}

private class FileZipSource(private val file: File) : SeekableZipSource {
    override fun open(): SeekableZipHandle {
        val randomFile = RandomAccessFile(file, "r")
        return SeekableZipHandle(randomFile.channel, 0L, randomFile.length()) {
            randomFile.close()
        }
    }
}

private class AssetZipSource(
    private val assets: AssetManager,
    private val assetName: String,
) : SeekableZipSource {
    override fun open(): SeekableZipHandle {
        val descriptor = assets.openFd(assetName)
        val baseOffset = descriptor.startOffset
        val length = descriptor.length
        val input = try {
            // AssetFileDescriptor documents that this auto-closing stream takes ownership of
            // the descriptor. Its `use` closes both without a second descriptor close.
            descriptor.createInputStream()
        } catch (error: Exception) {
            descriptor.close()
            throw error
        }
        return SeekableZipHandle(input.channel, baseOffset, length) { input.close() }
    }
}

private class SeekableZipHandle(
    val channel: FileChannel,
    val baseOffset: Long,
    val length: Long,
    private val closeOwner: () -> Unit,
) : java.io.Closeable {
    override fun close() = closeOwner()
}

/** A non-owning, bounded positional view. Its enclosing [SeekableZipSource] owns the channel. */
private class ChannelRangeInputStream(
    private val channel: FileChannel,
    private var start: Long,
    length: Long,
) : InputStream() {
    var bytesRemaining = length
        private set

    override fun read(): Int {
        val one = ByteArray(1)
        return if (read(one, 0, 1) < 0) -1 else one[0].toInt() and 0xff
    }

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        if (length == 0) return 0
        if (bytesRemaining == 0L) return -1
        val count = minOf(length.toLong(), bytesRemaining).toInt()
        val byteBuffer = ByteBuffer.wrap(buffer, offset, count)
        var read = channel.read(byteBuffer, start)
        while (read == 0) read = channel.read(byteBuffer, start)
        if (read < 0) throw IOException("ZIP entry ended unexpectedly")
        start += read
        bytesRemaining -= read
        return read
    }
}
