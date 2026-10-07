package com.dkaluta.prosary.ui

import com.dkaluta.prosary.ui.home.HomePhotoStore
import java.nio.file.Files
import org.junit.Assert.*
import org.junit.Test

class HomePhotoStoreTest {
    @Test fun removingACardDeletesOnlyItsPrivatePhotoAndCannotDeleteUnrelatedFiles() {
        val root = Files.createTempDirectory("prosary-home-photo").toFile()
        try {
            val directory = root.resolve("homePhotos").apply { mkdirs() }
            val photo = directory.resolve("home-photo-example.jpg").apply { writeText("photo") }
            val unrelated = root.resolve("prayerpacks/home-photo-other.jpg").apply { requireNotNull(parentFile).mkdirs(); writeText("pack") }
            HomePhotoStore.remove(root, unrelated.path)
            assertTrue(unrelated.exists())
            assertNull(HomePhotoStore.privateFile(root, directory.resolve("../prayerpacks/home-photo-other.jpg").path))
            assertNull(HomePhotoStore.privateFile(root, ""))
            HomePhotoStore.remove(root, photo.path)
            assertFalse(photo.exists())
            HomePhotoStore.remove(root, photo.path)
            assertTrue(unrelated.exists())
        } finally { root.deleteRecursively() }
    }
}
