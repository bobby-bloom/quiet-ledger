package dev.personalfinance.personal_finance

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Backup folder access through the Storage Access Framework
 * (`personal_finance/backup_folder`). The folder is a document tree URI
 * picked with ACTION_OPEN_DOCUMENT_TREE whose permission is persisted, so
 * scheduled backups keep working after a restart. Works with local storage
 * and cloud providers (Drive, Nextcloud, ...). See docs/BACKUP.md.
 *
 * Methods (folder = tree URI string):
 *  - pick -> {folder, name} or null when cancelled
 *  - check(folder) -> whether the persisted permission still exists
 *  - write(folder, name, bytes): temp document + rename, falls back to a
 *    direct write where the provider cannot rename (Dart reads it back)
 *  - read(folder, name) -> bytes or null
 *  - list(folder) -> file names
 *  - delete(folder, name)
 * Errors: code "access" when the permission is gone, "io" otherwise.
 */
class BackupFolderChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, NAME)
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(::onCall)
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "pick") {
            pick(result)
            return
        }
        val folder = call.argument<String>("folder")
        if (folder == null) {
            result.error("io", "No folder", null)
            return
        }
        val tree = Uri.parse(folder)
        io.execute {
            try {
                val value: Any? = when (call.method) {
                    "check" -> hasPermission(tree)
                    "write" -> {
                        requireAccess(tree)
                        write(tree, call.argument<String>("name")!!, call.argument<ByteArray>("bytes")!!)
                        null
                    }
                    "read" -> {
                        requireAccess(tree)
                        read(tree, call.argument<String>("name")!!)
                    }
                    "list" -> {
                        requireAccess(tree)
                        children(tree).keys.toList()
                    }
                    "delete" -> {
                        requireAccess(tree)
                        children(tree)[call.argument<String>("name")!!]?.let {
                            DocumentsContract.deleteDocument(activity.contentResolver, it)
                        }
                        null
                    }
                    else -> {
                        main.post { result.notImplemented() }
                        return@execute
                    }
                }
                main.post { result.success(value) }
            } catch (e: AccessException) {
                main.post { result.error("access", e.message, null) }
            } catch (e: SecurityException) {
                main.post { result.error("access", e.message, null) }
            } catch (e: Exception) {
                main.post { result.error("io", e.message ?: e.toString(), null) }
            }
        }
    }

    private fun pick(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("io", "Folder picker already open", null)
            return
        }
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
        )
        activity.startActivityForResult(intent, REQUEST_CODE)
    }

    /** Forwarded from MainActivity.onActivityResult. Returns true when handled. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        try {
            activity.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            result.success(mapOf("folder" to uri.toString(), "name" to displayName(uri)))
        } catch (e: Exception) {
            result.error("access", e.message ?: e.toString(), null)
        }
        return true
    }

    private fun hasPermission(tree: Uri): Boolean =
        activity.contentResolver.persistedUriPermissions.any {
            it.uri == tree && it.isReadPermission && it.isWritePermission
        }

    private fun requireAccess(tree: Uri) {
        if (!hasPermission(tree)) throw AccessException("No access to the backup folder")
    }

    private fun treeDocument(tree: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))

    /** Display name → document URI of the folder's direct children. */
    private fun children(tree: Uri): Map<String, Uri> {
        val parentId = DocumentsContract.getTreeDocumentId(tree)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        val out = LinkedHashMap<String, Uri>()
        activity.contentResolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            ),
            null,
            null,
            null,
        )?.use { c ->
            while (c.moveToNext()) {
                if (c.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) continue
                out[c.getString(1)] = DocumentsContract.buildDocumentUriUsingTree(tree, c.getString(0))
            }
        }
        return out
    }

    private fun write(tree: Uri, name: String, bytes: ByteArray) {
        val resolver = activity.contentResolver
        val parent = treeDocument(tree)
        val existing = children(tree)
        val tmpName = ".$name.tmp"
        existing[tmpName]?.let { DocumentsContract.deleteDocument(resolver, it) }
        val tmp = DocumentsContract.createDocument(resolver, parent, MIME, tmpName)
            ?: throw IllegalStateException("Could not create $tmpName")
        writeBytes(tmp, bytes)
        val renamed = try {
            existing[name]?.let { DocumentsContract.deleteDocument(resolver, it) }
            DocumentsContract.renameDocument(resolver, tmp, name)
        } catch (e: UnsupportedOperationException) {
            null
        }
        if (renamed == null) {
            // Provider without rename: write the target directly; Dart
            // verifies the result by reading it back.
            val target = children(tree)[name]
                ?: DocumentsContract.createDocument(resolver, parent, MIME, name)
                ?: throw IllegalStateException("Could not create $name")
            writeBytes(target, bytes)
            DocumentsContract.deleteDocument(resolver, tmp)
        }
    }

    /** "wt" (truncate) where supported; some providers only accept "w". */
    private fun writeBytes(doc: Uri, bytes: ByteArray) {
        val resolver = activity.contentResolver
        val out = try {
            resolver.openOutputStream(doc, "wt")
        } catch (e: Exception) {
            null
        } ?: resolver.openOutputStream(doc, "w")
            ?: throw IllegalStateException("Cannot write $doc")
        out.use { it.write(bytes) }
    }

    private fun read(tree: Uri, name: String): ByteArray? {
        val doc = children(tree)[name] ?: return null
        return activity.contentResolver.openInputStream(doc)?.use { it.readBytes() }
    }

    private fun displayName(tree: Uri): String {
        val doc = treeDocument(tree)
        activity.contentResolver.query(
            doc,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { c -> if (c.moveToFirst()) return c.getString(0) }
        return tree.lastPathSegment ?: tree.toString()
    }

    private class AccessException(message: String) : Exception(message)

    companion object {
        const val NAME = "personal_finance/backup_folder"
        private const val REQUEST_CODE = 0x6b61
        private const val MIME = "application/octet-stream"
    }
}
