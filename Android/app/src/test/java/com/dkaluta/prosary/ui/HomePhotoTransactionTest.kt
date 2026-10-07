package com.dkaluta.prosary.ui

import com.dkaluta.prosary.ui.home.HomePhotoTransaction
import java.nio.file.Files
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.junit.Assert.*
import org.junit.Test

class HomePhotoTransactionTest {
    @Test fun navigationDuringCopyRemovesTheCandidateAndKeepsThePreviousSelection() = runBlocking {
        val directory = Files.createTempDirectory("prosary-home-cancelled-copy").toFile()
        val previous = directory.resolve("old.jpg").apply { writeText("old") }
        val candidate = directory.resolve("new.jpg")
        var selection = previous.path
        val copied = CountDownLatch(1)
        val finishCopy = CountDownLatch(1)
        try {
            val operation = launch {
                HomePhotoTransaction.replace(selection, {
                    candidate.writeText("new")
                    copied.countDown()
                    check(finishCopy.await(5, TimeUnit.SECONDS))
                    candidate.path
                }, { selection = it }, { directory.resolve(it).delete() })
            }
            assertTrue(withContext(Dispatchers.IO) { copied.await(5, TimeUnit.SECONDS) })
            operation.cancel()
            finishCopy.countDown()
            operation.join()
            assertEquals(previous.path, selection)
            assertTrue(previous.exists())
            assertFalse(candidate.exists())
        } finally { finishCopy.countDown(); directory.deleteRecursively() }
    }

    @Test fun successfulReplacementKeepsOnlyTheNewPrivateCopy() = runBlocking {
        val directory = Files.createTempDirectory("prosary-home-replace").toFile()
        try {
            val previous = directory.resolve("old.jpg").apply { writeText("old") }
            val candidate = directory.resolve("new.jpg")
            var selection = previous.path
            HomePhotoTransaction.replace(selection, { candidate.writeText("new"); candidate.path },
                { selection = it }, { java.io.File(it).delete() })
            assertEquals(candidate.path, selection)
            assertTrue(candidate.exists())
            assertFalse(previous.exists())
        } finally { directory.deleteRecursively() }
    }

    @Test fun navigationDuringDeletionStillClearsTheDeletedPhotosPreference() = runBlocking {
        val directory = Files.createTempDirectory("prosary-home-cancelled-delete").toFile()
        val previous = directory.resolve("old.jpg").apply { writeText("old") }
        var selection = previous.path
        val deleting = CountDownLatch(1)
        val finishDelete = CountDownLatch(1)
        try {
            val operation = launch {
                HomePhotoTransaction.remove(selection, {
                    deleting.countDown()
                    check(finishDelete.await(5, TimeUnit.SECONDS))
                    java.io.File(it).delete()
                }, { selection = "" })
            }
            assertTrue(withContext(Dispatchers.IO) { deleting.await(5, TimeUnit.SECONDS) })
            operation.cancel()
            finishDelete.countDown()
            operation.join()
            assertEquals("", selection)
            assertFalse(previous.exists())
        } finally { finishDelete.countDown(); directory.deleteRecursively() }
    }
}
