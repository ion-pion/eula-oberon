package ro.jahbalon.webapp;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.WindowManager;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;

/**
 * Pielea aplicatiilor facute cu "html" in Eula: un WebView pe tot ecranul care deschide assets/index.html.
 * Paginile vin de la o adresa https locala (ca WebViewAssetLoader), nu din file:// - asa merg fetch, modulele JS,
 * sunetele incarcate din fisiere si localStorage, exact ca pe un site. Compilata o data, cand se construieste Eula
 * (pagina.dex); Eula o pune neschimbata in fiecare aplicatie.
 */
public class Pagina extends Activity {
    static final String GAZDA = "https://appassets.androidplatform.net/";
    WebView w;

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        w = new WebView(this);
        WebSettings s = w.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setUseWideViewPort(true);
        s.setLoadWithOverviewMode(true);
        w.setWebChromeClient(new WebChromeClient());
        w.setWebViewClient(new WebViewClient() {
            @Override public WebResourceResponse shouldInterceptRequest(WebView v, WebResourceRequest r) {
                return dinAplicatie(r.getUrl().toString());
            }
            @SuppressWarnings("deprecation")
            @Override public WebResourceResponse shouldInterceptRequest(WebView v, String url) {
                return dinAplicatie(url);
            }
            @SuppressWarnings("deprecation")
            @Override public boolean shouldOverrideUrlLoading(WebView v, String url) {
                if (url.startsWith(GAZDA)) return false;
                try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url))); } catch (Exception e) { /* nimic */ }
                return true;   // legaturile spre internet se deschid in browser
            }
        });
        setContentView(w);
        if (b == null || w.restoreState(b) == null) w.loadUrl(GAZDA + "index.html");
    }

    /** fisierele din assets/, servite de la GAZDA */
    WebResourceResponse dinAplicatie(String url) {
        if (!url.startsWith(GAZDA)) return null;
        String c = url.substring(GAZDA.length());
        int k = c.indexOf('?'); if (k >= 0) c = c.substring(0, k);
        k = c.indexOf('#'); if (k >= 0) c = c.substring(0, k);
        c = Uri.decode(c);
        if (c.isEmpty() || c.endsWith("/")) c += "index.html";
        Map<String, String> antet = new HashMap<String, String>();
        antet.put("Access-Control-Allow-Origin", "*");
        antet.put("Cache-Control", "no-cache");
        try {
            InputStream in = getAssets().open(c);
            String tip = tip(c);
            boolean text = tip.startsWith("text/") || tip.endsWith("javascript") || tip.endsWith("json") || tip.endsWith("svg+xml");
            return new WebResourceResponse(tip, text ? "UTF-8" : null, 200, "OK", antet, in);
        } catch (Exception e) {
            return new WebResourceResponse("text/plain", "UTF-8", 404, "Not Found", antet,
                new ByteArrayInputStream(("nu exista: " + c).getBytes()));
        }
    }

    static final Map<String, String> TIPURI = new HashMap<String, String>();
    static {
        String[] t = {
            "html", "text/html", "htm", "text/html", "js", "text/javascript", "mjs", "text/javascript",
            "css", "text/css", "json", "application/json", "txt", "text/plain", "xml", "text/xml", "csv", "text/csv",
            "svg", "image/svg+xml", "png", "image/png", "jpg", "image/jpeg", "jpeg", "image/jpeg", "gif", "image/gif",
            "webp", "image/webp", "ico", "image/x-icon", "bmp", "image/bmp",
            "wav", "audio/wav", "mp3", "audio/mpeg", "ogg", "audio/ogg", "oga", "audio/ogg", "m4a", "audio/mp4",
            "flac", "audio/flac", "mid", "audio/midi", "midi", "audio/midi",
            "mp4", "video/mp4", "webm", "video/webm", "ogv", "video/ogg",
            "woff", "font/woff", "woff2", "font/woff2", "ttf", "font/ttf", "otf", "font/otf",
            "wasm", "application/wasm", "glb", "model/gltf-binary", "gltf", "model/gltf+json", "pdf", "application/pdf"};
        for (int i = 0; i < t.length; i += 2) TIPURI.put(t[i], t[i + 1]);
    }

    static String tip(String c) {
        int p = c.lastIndexOf('.');
        String t = p < 0 ? null : TIPURI.get(c.substring(p + 1).toLowerCase());
        return t == null ? "application/octet-stream" : t;
    }

    @Override protected void onSaveInstanceState(Bundle b) {
        super.onSaveInstanceState(b);
        w.saveState(b);
    }

    @Override public void onBackPressed() {
        if (w.canGoBack()) w.goBack(); else super.onBackPressed();
    }

    @Override protected void onPause() { w.onPause(); super.onPause(); }
    @Override protected void onResume() { super.onResume(); w.onResume(); }
    @Override protected void onDestroy() { w.destroy(); super.onDestroy(); }
}
