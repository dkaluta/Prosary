package com.dkaluta.prosary.content.bible

import com.dkaluta.prosary.content.today.ReadingSourceNote
import com.dkaluta.prosary.content.today.ReadingVerse
import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.*

@Serializable
@OptIn(ExperimentalSerializationApi::class)
data class BibleAddress(val chapter: Int, val verse: Int,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val endVerse: Int? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val part: String? = null) {
    val lastVerse: Int get() = endVerse ?: verse
    fun validate() {
        require(chapter in 1..1000 && verse in 1..1000 && lastVerse in verse..1000)
        require(part == null || part.isNotBlank())
    }
    fun overlaps(other: BibleAddress) = chapter == other.chapter && verse <= other.lastVerse && other.verse <= lastVerse
}

@Serializable
data class BibleAddressRoute(val chapter: Int, val verse: Int, val displayChapter: Int, val blockId: String)

@Serializable(with = BibleContentBlockSerializer::class)
data class BibleContentBlock(val id: String, val kind: String, val chapter: Int? = null,
    val verse: Int? = null, val printedLabel: String? = null, val text: String? = null,
    val addresses: List<BibleAddress>? = null, val sourceNotes: List<ReadingSourceNote>? = null) {
    fun validate() {
        require(BibleSourceStructure.ID.matches(id))
        require(printedLabel == null || printedLabel.isNotBlank())
        when (kind) {
            "verse" -> require(chapter != null && chapter in 1..1000 && verse != null && verse in 1..1000 && text == null && addresses == null && sourceNotes == null)
            "witness" -> {
                require(chapter == null && verse == null && !printedLabel.isNullOrBlank() && !text.isNullOrBlank())
                require(!addresses.isNullOrEmpty() && addresses.map { listOf(it.chapter, it.verse, it.lastVerse, it.part) }.distinct().size == addresses.size)
                addresses.forEach { it.validate() }
            }
            "passage", "heading", "colophon" -> {
                require(chapter == null && verse == null && printedLabel == null && addresses == null && !text.isNullOrBlank())
                require(kind != "heading" || sourceNotes == null)
            }
            else -> throw IllegalArgumentException("Unknown Bible content block")
        }
    }
}

@Serializable
@OptIn(ExperimentalSerializationApi::class)
private data class BlockFields(val id: String, val kind: String,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val chapter: Int? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val verse: Int? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val printedLabel: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val text: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val addresses: List<BibleAddress>? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val sourceNotes: List<ReadingSourceNote>? = null)

object BibleContentBlockSerializer : KSerializer<BibleContentBlock> {
    override val descriptor: SerialDescriptor = BlockFields.serializer().descriptor
    override fun deserialize(decoder: Decoder): BibleContentBlock {
        val input = decoder as? JsonDecoder ?: throw SerializationException("Bible blocks require JSON")
        val value = input.decodeJsonElement().jsonObject
        val kind = value["kind"]?.jsonPrimitive?.content
        val (required, optional) = when (kind) {
            "verse" -> setOf("id", "kind", "chapter", "verse") to setOf("printedLabel")
            "witness" -> setOf("id", "kind", "text", "printedLabel", "addresses") to setOf("sourceNotes")
            "passage", "colophon" -> setOf("id", "kind", "text") to setOf("sourceNotes")
            "heading" -> setOf("id", "kind", "text") to emptySet()
            else -> throw SerializationException("Unknown Bible block kind")
        }
        strictFields(value, required, optional)
        listOf("id", "kind", "text", "printedLabel").filter { it in value }.forEach { strictString(value, it) }
        listOf("chapter", "verse").filter { it in value }.forEach { strictInteger(value, it) }
        if ("addresses" in value) {
            val addresses = value["addresses"] as? JsonArray ?: throw SerializationException("Invalid addresses")
            require(addresses.isNotEmpty())
            addresses.forEach {
                val address = it.jsonObject
                strictFields(address, setOf("chapter", "verse"), setOf("endVerse", "part"))
                listOf("chapter", "verse", "endVerse").filter { key -> key in address }.forEach { key -> strictInteger(address, key) }
                if ("part" in address) strictString(address, "part")
            }
        }
        if ("sourceNotes" in value) require((value["sourceNotes"] as? JsonArray)?.isNotEmpty() == true)
        val fields = input.json.decodeFromJsonElement<BlockFields>(value)
        return with(fields) { BibleContentBlock(id, kind, chapter, verse, printedLabel, text, addresses, sourceNotes) }.also { it.validate() }
    }
    override fun serialize(encoder: Encoder, value: BibleContentBlock) {
        val output = encoder as? JsonEncoder ?: throw SerializationException("Bible blocks require JSON")
        val fields = with(value) { BlockFields(id, kind, chapter, verse, printedLabel, text, addresses, sourceNotes) }
        output.encodeJsonElement(output.json.encodeToJsonElement(fields))
    }
}

internal fun strictFields(value: JsonObject, required: Set<String>, optional: Set<String> = emptySet()) {
    require(value.keys.containsAll(required) && (value.keys - required - optional).isEmpty() && value.values.none { it == JsonNull })
}
internal fun strictInteger(value: JsonObject, key: String) {
    val primitive = value[key] as? JsonPrimitive
    require(primitive != null && !primitive.isString && primitive.intOrNull != null)
}
internal fun strictString(value: JsonObject, key: String) {
    require((value[key] as? JsonPrimitive)?.isString == true)
}

/** A resolved display item keeps its physical identity separate from its numeric address. */
data class BibleDisplayItem(val block: BibleContentBlock, val primary: ReadingVerse? = null) {
    val id: String get() = block.id
    val addresses: List<BibleAddress> get() = primary?.let { listOf(BibleAddress(it.chapter, it.verse, it.endVerse)) } ?: block.addresses.orEmpty()
    val sourceNotes: List<ReadingSourceNote>? get() = primary?.sourceNotes ?: block.sourceNotes
}
data class BibleDisplayChapter(val chapter: BibleChapter, val items: List<BibleDisplayItem>)
data class BibleTarget(val displayChapter: Int, val blockId: String)

object BibleSourceStructure {
    internal val ID = Regex("[a-z0-9][a-z0-9-]*")
    fun implicitId(chapter: Int, verse: Int) = "primary-$chapter-$verse"
    fun blocks(chapter: BibleChapter): List<BibleContentBlock> = chapter.contentBlocks ?: chapter.verses.map {
        BibleContentBlock(implicitId(it.chapter, it.verse), "verse", it.chapter, it.verse)
    }
    /** Called only after all chapter payloads and note anchors have been validated. */
    fun validate(book: BibleBook, chapters: List<BibleChapter>) {
        val byChapter = chapters.associateBy { it.chapter }
        require(byChapter.size == chapters.size && byChapter.keys == book.chapters.map { it.number }.toSet())
        val primary = chapters.flatMap { it.verses }.associateBy { it.chapter to it.verse }
        val presented = mutableSetOf<Pair<Int, Int>>()
        val blockIds = mutableSetOf<String>()
        val expectedRoutes = mutableSetOf<BibleAddressRoute>()
        chapters.forEach { chapter ->
            blocks(chapter).forEach { block ->
                block.validate()
                // Synthetic implicit IDs are not authored block IDs.
                if (chapter.contentBlocks != null) require(blockIds.add(block.id))
                if (block.kind == "verse") {
                    val address = requireNotNull(block.chapter) to requireNotNull(block.verse)
                    require(address in primary && presented.add(address))
                    if (block.chapter != chapter.chapter) expectedRoutes.add(BibleAddressRoute(address.first, address.second, chapter.chapter, block.id))
                }
                block.addresses.orEmpty().forEach { require(it.chapter in byChapter) }
            }
        }
        require(presented == primary.keys)
        val routes = book.addressRoutes.orEmpty()
        require(routes.distinct().size == routes.size && routes.map { it.chapter to it.verse }.distinct().size == routes.size)
        require(routes.toSet() == expectedRoutes)
    }
    fun resolve(chapter: BibleChapter, loadPrimary: (Int) -> BibleChapter?): BibleDisplayChapter {
        val loaded = mutableMapOf(chapter.chapter to chapter)
        val items = blocks(chapter).map { block ->
            val primary = if (block.kind == "verse") {
                val number = requireNotNull(block.chapter)
                val source = loaded.getOrPut(number) { requireNotNull(loadPrimary(number)) }
                source.verses.single { it.verse == block.verse }
            } else null
            BibleDisplayItem(block, primary)
        }
        return BibleDisplayChapter(chapter, items)
    }
    /** Numeric requests prefer the primary unit even when a witness shares its address. */
    fun target(book: BibleBook, source: BibleChapter, verse: Int): BibleTarget? {
        val unit = source.verses.firstOrNull { verse in it.verse..it.lastVerse } ?: return null
        book.addressRoutes.orEmpty().firstOrNull { it.chapter == unit.chapter && it.verse == unit.verse }?.let {
            return BibleTarget(it.displayChapter, it.blockId)
        }
        val block = blocks(source).singleOrNull { it.kind == "verse" && it.chapter == unit.chapter && it.verse == unit.verse } ?: return null
        return BibleTarget(source.chapter, block.id)
    }
    fun occurrence(items: List<BibleDisplayItem>, index: Int): Int? {
        val item = items[index]
        if (item.block.kind != "witness") return null
        fun matches(other: BibleDisplayItem) = item.addresses.any { a -> other.addresses.any(a::overlaps) }
        if (items.indices.none { it != index && matches(items[it]) }) return null
        return items.take(index).count(::matches) + 1
    }
}
