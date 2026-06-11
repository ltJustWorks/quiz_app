package com.example.quiz_app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val syncChannelName = "quiz_app/android_sync_folder"
    private val openTreeRequestCode = 4601
    private var pendingFolderResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            syncChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "selectSyncFolder" -> selectSyncFolder(result)
                "validateSyncFolder" -> {
                    val folderUri = call.argument<String>("folderUri")
                    validateSyncFolder(folderUri, result)
                }
                "readSyncFile" -> {
                    val folderUri = call.argument<String>("folderUri")
                    val fileName = call.argument<String>("fileName")
                    readSyncFile(folderUri, fileName, result)
                }
                "writeSyncFile" -> {
                    val folderUri = call.argument<String>("folderUri")
                    val fileName = call.argument<String>("fileName")
                    val content = call.argument<String>("content")
                    writeSyncFile(folderUri, fileName, content, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun selectSyncFolder(result: MethodChannel.Result) {
        if (pendingFolderResult != null) {
            result.error("folder_picker_active", "A folder picker is already open.", null)
            return
        }

        pendingFolderResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }

        startActivityForResult(intent, openTreeRequestCode)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != openTreeRequestCode) return

        val result = pendingFolderResult
        pendingFolderResult = null

        if (result == null) return

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val folderUri = data.data!!
        val permissionFlags = data.flags and (
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        )

        try {
            contentResolver.takePersistableUriPermission(folderUri, permissionFlags)
            result.success(folderUri.toString())
        } catch (error: Exception) {
            result.error(
                "persist_permission_failed",
                "Could not persist access to the selected folder.",
                error.toString()
            )
        }
    }

    private fun validateSyncFolder(folderUri: String?, result: MethodChannel.Result) {
        if (folderUri.isNullOrBlank()) {
            result.error("missing_folder_uri", "Missing sync folder URI.", null)
            return
        }

        try {
            val uri = Uri.parse(folderUri)
            val probeName = ".quizgpt_write_test"
            writeFile(uri, probeName, "ok")
            deleteFileIfExists(uri, probeName)
            result.success(true)
        } catch (error: Exception) {
            result.error("folder_not_writable", "The selected folder is not writable.", error.toString())
        }
    }

    private fun readSyncFile(folderUri: String?, fileName: String?, result: MethodChannel.Result) {
        if (folderUri.isNullOrBlank() || fileName.isNullOrBlank()) {
            result.error("missing_argument", "Missing folderUri or fileName.", null)
            return
        }

        try {
            val treeUri = Uri.parse(folderUri)
            val documentUri = findChildDocumentUri(treeUri, fileName)
            if (documentUri == null) {
                result.success(null)
                return
            }

            val content = contentResolver.openInputStream(documentUri)?.use { input ->
                input.bufferedReader().use { it.readText() }
            }
            result.success(content)
        } catch (error: Exception) {
            result.error("read_sync_file_failed", "Could not read sync file.", error.toString())
        }
    }

    private fun writeSyncFile(
        folderUri: String?,
        fileName: String?,
        content: String?,
        result: MethodChannel.Result
    ) {
        if (folderUri.isNullOrBlank() || fileName.isNullOrBlank() || content == null) {
            result.error("missing_argument", "Missing folderUri, fileName, or content.", null)
            return
        }

        try {
            writeFile(Uri.parse(folderUri), fileName, content)
            result.success(true)
        } catch (error: Exception) {
            result.error("write_sync_file_failed", "Could not write sync file.", error.toString())
        }
    }

    private fun writeFile(treeUri: Uri, fileName: String, content: String) {
        val documentUri = findChildDocumentUri(treeUri, fileName)
            ?: DocumentsContract.createDocument(
                contentResolver,
                treeDocumentUri(treeUri),
                "application/json",
                fileName
            )
            ?: throw IllegalStateException("Could not create $fileName")

        contentResolver.openOutputStream(documentUri, "wt")?.use { output ->
            output.write(content.toByteArray(Charsets.UTF_8))
        } ?: throw IllegalStateException("Could not open $fileName for writing")
    }

    private fun deleteFileIfExists(treeUri: Uri, fileName: String) {
        val documentUri = findChildDocumentUri(treeUri, fileName) ?: return
        DocumentsContract.deleteDocument(contentResolver, documentUri)
    }

    private fun treeDocumentUri(treeUri: Uri): Uri {
        val documentId = DocumentsContract.getTreeDocumentId(treeUri)
        return DocumentsContract.buildDocumentUriUsingTree(treeUri, documentId)
    }

    private fun findChildDocumentUri(treeUri: Uri, fileName: String): Uri? {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri)
        )

        contentResolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME
            ),
            null,
            null,
            null
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)

            while (cursor.moveToNext()) {
                if (cursor.getString(nameIndex) == fileName) {
                    return DocumentsContract.buildDocumentUriUsingTree(treeUri, cursor.getString(idIndex))
                }
            }
        }

        return null
    }
}
