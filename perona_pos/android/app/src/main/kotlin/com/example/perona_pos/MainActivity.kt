package com.example.perona_pos

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val whatsappPackages = setOf("com.whatsapp", "com.whatsapp.w4b")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "id.peronasepatu/receipt_share")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "availableApps" -> result.success(whatsappPackages.filter { target ->
                            Intent(Intent.ACTION_SEND).apply {
                                type = "image/png"
                                setPackage(target)
                            }.resolveActivity(packageManager) != null
                        })
                        "shareImages" -> {
                            shareImages(call)
                            // This confirms only that WhatsApp opened, never delivery.
                            result.success(null)
                        }
                        "openChat" -> {
                            val (target, phone) = destination(call)
                            startActivity(Intent(Intent.ACTION_VIEW,
                                Uri.parse("https://wa.me/$phone")).setPackage(target))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: ActivityNotFoundException) {
                    result.error("whatsapp_unavailable", "WhatsApp belum tersedia.", null)
                } catch (_: Exception) {
                    result.error("receipt_share_failed", "Gambar nota belum bisa dibagikan.", null)
                }
            }
    }

    private fun destination(call: MethodCall): Pair<String, String> {
        val target = call.argument<String>("package")
        val phone = call.argument<String>("phone") ?: ""
        require(target in whatsappPackages && phone.matches(Regex("[1-9][0-9]{7,14}")))
        return Pair(target!!, phone)
    }

    private fun shareImages(call: MethodCall) {
        val (target, phone) = destination(call)
        val images = call.argument<List<Map<String, Any>>>("images") ?: emptyList()
        require(images.isNotEmpty())
        val directory = File(cacheDir, "receipt-shares").apply { mkdirs() }
        // Keep recent attachments available if WhatsApp is still reading them.
        val cutoff = System.currentTimeMillis() - 48L * 60 * 60 * 1000
        directory.listFiles()?.filter { it.isFile && it.lastModified() < cutoff }
            ?.forEach { it.delete() }
        val uris = ArrayList<Uri>()
        for (image in images) {
            val bytes = image["bytes"] as? ByteArray ?: error("Missing PNG")
            val name = image["name"] as? String ?: error("Missing filename")
            require(name.matches(Regex("[a-zA-Z0-9_-]+\\.png")) && bytes.isNotEmpty())
            val file = File(directory, "${UUID.randomUUID()}-$name")
            file.writeBytes(bytes)
            uris.add(FileProvider.getUriForFile(this, "$packageName.receipt_files", file))
        }
        val intent = Intent(if (uris.size == 1) Intent.ACTION_SEND else Intent.ACTION_SEND_MULTIPLE).apply {
            type = "image/png"
            setPackage(target)
            if (uris.size == 1) putExtra(Intent.EXTRA_STREAM, uris.first())
            else putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
            putExtra(Intent.EXTRA_TEXT, call.argument<String>("caption"))
            // WhatsApp-specific best-effort hint, not a public Android contract.
            // Some WhatsApp versions still show the recipient picker. The UI
            // explains this and provides an explicit wa.me fallback.
            putExtra("jid", "$phone@s.whatsapp.net")
            clipData = ClipData.newUri(contentResolver, "Nota Perona", uris.first()).apply {
                uris.drop(1).forEach { addItem(ClipData.Item(it)) }
            }
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
    }
}
