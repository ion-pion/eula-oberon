package ro.jahbalon.oberonapp;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.Typeface;
import android.net.Uri;
import android.text.SpannableStringBuilder;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.text.style.StyleSpan;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.view.inputmethod.EditorInfo;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.io.*;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.concurrent.LinkedBlockingQueue;

/**
 * Pielea aplicatiilor Oberon care vorbesc (modulul exporta Apasa*): titlu + stare, conversatia, casuta, doua randuri
 * de butoane. Modulul Oberon le umple prin Conversatie (vezi sistem/def/Conversatie.Mod). Tot ce cheama in Oberon
 * (Porneste, Apasa, Primeste, Pauza) merge pe un singur fir, pe rand; cat lucreaza, butoanele nu mai cheama nimic.
 */
public final class Vorbire {
    private Vorbire() {}
    static final int BG = 0xFF0E0A16, PANEL = 0xFF1A1426, GOLD = 0xFFFFC52E, DIM = 0xFF9C8FB8, TEXT = 0xFFF2EEF8, ROSU = 0xFFFF7A7A;
    static final int ALEGE = 4242;

    static Activity act;
    static Method apasa, porneste, primeste, pauza, tic;
    static volatile int ceasMs = 0;
    static volatile boolean ticAsteapta;
    static final android.os.Handler h = new android.os.Handler(android.os.Looper.getMainLooper());
    static TextView titlu, stare, log;
    static EditText casuta;
    static ScrollView scroll;
    static LinearLayout randMic, randMare;
    static final SpannableStringBuilder chat = new SpannableStringBuilder();
    static String titluT = "", stareT = "";
    static final String[] eticheta = new String[20];
    static final int[] fond = new int[20], scris = new int[20];
    static float marime = 17;
    static volatile boolean ocupat, pornit;
    static volatile int apasat;
    static volatile String intrare = "";
    public static volatile String alesCale = "", alesNume = "";
    static final long t0 = System.currentTimeMillis();
    static final LinkedBlockingQueue<Runnable> coada = new LinkedBlockingQueue<Runnable>();
    static Thread fir;

    static int dp(float v) { return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, act.getResources().getDisplayMetrics()); }
    static SharedPreferences pref() { return act.getSharedPreferences("oberon", 0); }

    // ------------------------------------------------------------------ firul Oberon

    static void lucreaza(Runnable r) {
        if (fir == null) {
            fir = new Thread(null, new Runnable() { public void run() {
                while (true) {
                    try { coada.take().run(); } catch (InterruptedException e) { return; } catch (Throwable t) { /* mai departe */ }
                }
            }}, "oberon", 64L << 20);
            fir.setDaemon(true);
            fir.start();
        }
        coada.add(r);
    }

    static String text(Throwable t) {
        while (t instanceof InvocationTargetException && ((InvocationTargetException) t).getTargetException() != null)
            t = ((InvocationTargetException) t).getTargetException();
        if (t instanceof ExceptionInInitializerError && t.getCause() != null) t = t.getCause();
        StackTraceElement[] st = t.getStackTrace();
        String unde = "";
        for (StackTraceElement e : st) if (!e.getClassName().startsWith("java.") && !e.getClassName().startsWith("android.")) {
            unde = " (în " + e.getClassName() + "." + e.getMethodName() + ")"; break;
        }
        return t.getClass().getSimpleName() + (t.getMessage() != null ? ": " + t.getMessage() : "") + unde;
    }

    /** cheama o procedura Oberon pe firul ei; daca se opreste, spune de ce si merge mai departe */
    static void cheama(Method m) {
        if (m == null) return;
        try { m.invoke(null); }
        catch (Throwable t) { spune(ROSU, "Modulul Oberon s-a oprit: ", text(t)); }
    }

    // ------------------------------------------------------------------ ecranul

    static void construieste(Activity a, Class<?> k) {
        act = a;
        apasa = metoda(k, "Apasa"); porneste = metoda(k, "Porneste"); primeste = metoda(k, "Primeste"); pauza = metoda(k, "Pauza"); tic = metoda(k, "Tic");
        marime = pref().getFloat("marime", 17);
        a.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        try { a.getWindow().setStatusBarColor(BG); a.getWindow().setNavigationBarColor(BG); } catch (Throwable t) { /* vechi */ }

        LinearLayout root = new LinearLayout(a);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(BG);
        root.setPadding(dp(12), dp(10), dp(12), dp(10));

        LinearLayout sus = new LinearLayout(a);
        sus.setGravity(Gravity.CENTER_VERTICAL);
        titlu = new TextView(a);
        titlu.setTextColor(GOLD);
        titlu.setTypeface(Typeface.DEFAULT_BOLD);
        titlu.setTextSize(28);
        titlu.setText(titluT);
        sus.addView(titlu);
        stare = new TextView(a);
        stare.setTextColor(DIM);
        stare.setTextSize(13);
        stare.setPadding(dp(12), 0, 0, 0);
        stare.setText(stareT);
        sus.addView(stare, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        sus.addView(mic("A−", new View.OnClickListener() { public void onClick(View v) { litere(-1); } }));
        sus.addView(mic("A+", new View.OnClickListener() { public void onClick(View v) { litere(+1); } }));
        root.addView(sus);

        scroll = new ScrollView(a);
        scroll.setBackgroundColor(PANEL);
        log = new TextView(a);
        log.setTextColor(TEXT);
        log.setTextSize(marime);
        log.setPadding(dp(14), dp(12), dp(14), dp(12));
        log.setTextIsSelectable(true);
        log.setText(chat);
        scroll.addView(log);
        LinearLayout.LayoutParams sp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1);
        sp.topMargin = dp(8);
        root.addView(scroll, sp);

        casuta = new EditText(a);
        casuta.setHint("Scrie aici…");
        casuta.setHintTextColor(DIM);
        casuta.setTextColor(TEXT);
        casuta.setBackgroundColor(PANEL);
        casuta.setPadding(dp(14), dp(12), dp(14), dp(12));
        casuta.setImeOptions(EditorInfo.IME_ACTION_SEND);
        casuta.setOnEditorActionListener(new TextView.OnEditorActionListener() {
            public boolean onEditorAction(TextView v, int x, KeyEvent e) { apasa(0); return true; }
        });
        LinearLayout.LayoutParams ip = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        ip.topMargin = dp(8);
        root.addView(casuta, ip);

        randMic = new LinearLayout(a);
        LinearLayout.LayoutParams gl = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        gl.topMargin = dp(8);
        root.addView(randMic, gl);
        randMare = new LinearLayout(a);
        LinearLayout.LayoutParams rp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        rp.topMargin = dp(8);
        root.addView(randMare, rp);
        butoane();
        a.setContentView(root);
        scroll.post(new Runnable() { public void run() { scroll.fullScroll(View.FOCUS_DOWN); } });

        if (!pornit) {
            pornit = true;
            ocupat = true;
            lucreaza(new Runnable() { public void run() { cheama(porneste); ocupat = false; } });
        }
    }

    static Method metoda(Class<?> k, String n) {
        try { return k.getMethod(n); } catch (NoSuchMethodException e) { return null; }
    }

    static TextView mic(String t, View.OnClickListener l) {
        TextView v = new TextView(act);
        v.setText(t);
        v.setTextColor(GOLD);
        v.setTextSize(20);
        v.setTypeface(Typeface.DEFAULT_BOLD);
        v.setPadding(dp(14), dp(8), dp(14), dp(8));
        v.setOnClickListener(l);
        return v;
    }

    static void litere(int d) {
        marime = Math.max(12, Math.min(30, marime + d * 2));
        log.setTextSize(marime);
        pref().edit().putFloat("marime", marime).apply();
    }

    /** refac randurile de butoane din ce a cerut modulul (1..8 mici, 11..18 mari) */
    static void butoane() {
        if (randMic == null) return;
        randMic.removeAllViews();
        randMare.removeAllViews();
        for (int nr = 1; nr < 20; nr++) {
            if (eticheta[nr] == null || eticheta[nr].isEmpty()) continue;
            final int n = nr;
            boolean mare = nr >= 11;
            Button b = new Button(act);
            b.setText(eticheta[nr]);
            b.setAllCaps(false);
            b.setTextSize(mare ? 19 : 14);
            b.setTypeface(Typeface.DEFAULT_BOLD);
            b.setPadding(0, 0, 0, 0);
            b.setTextColor(scris[nr]);
            b.setBackgroundColor(fond[nr]);
            b.setOnClickListener(new View.OnClickListener() { public void onClick(View v) { apasa(n); } });
            LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(0, dp(mare ? 58 : 44), 1);
            p.setMargins(dp(4), 0, dp(4), 0);
            (mare ? randMare : randMic).addView(b, p);
        }
        randMic.setVisibility(randMic.getChildCount() > 0 ? View.VISIBLE : View.GONE);
        randMare.setVisibility(randMare.getChildCount() > 0 ? View.VISIBLE : View.GONE);
    }

    static void pe(Runnable r) { if (act != null) act.runOnUiThread(r); }

    // ------------------------------------------------------------------ ce face omul

    static void apasa(final int nr) {
        if (ocupat) return;
        ocupat = true;
        intrare = casuta.getText().toString();
        apasat = nr;
        lucreaza(new Runnable() { public void run() { cheama(apasa); ocupat = false; } });
    }

    static void pauza() {
        if (pauza != null && pornit) lucreaza(new Runnable() { public void run() { cheama(pauza); } });
    }

    static void rezultat(int req, int res, Intent data) {
        if (req != ALEGE) return;
        final Uri u = res == Activity.RESULT_OK && data != null ? data.getData() : null;
        ocupat = true;
        lucreaza(new Runnable() { public void run() {
            alesCale = ""; alesNume = "";
            if (u != null) {
                try {
                    File f = new File(act.getFilesDir(), "ales.tmp");
                    InputStream i = act.getContentResolver().openInputStream(u);
                    OutputStream o = new FileOutputStream(f);
                    byte[] b = new byte[1 << 16];
                    int k;
                    while ((k = i.read(b)) > 0) o.write(b, 0, k);
                    o.close(); i.close();
                    alesCale = f.getAbsolutePath();
                    alesNume = numele(u);
                } catch (Throwable t) { spune(ROSU, "", "Nu pot citi fișierul: " + text(t)); alesCale = ""; }
            }
            cheama(primeste);
            ocupat = false;
        }});
    }

    static String numele(Uri u) {
        try {
            android.database.Cursor c = act.getContentResolver().query(u, new String[] {android.provider.OpenableColumns.DISPLAY_NAME}, null, null, null);
            if (c != null) {
                String n = c.moveToFirst() && !c.isNull(0) ? c.getString(0) : null;
                c.close();
                if (n != null) return n;
            }
        } catch (Throwable t) { /* fara nume */ }
        return u.getLastPathSegment() != null ? u.getLastPathSegment() : "fișier";
    }

    // ------------------------------------------------------------------ ce cere modulul (prin Conversatie)

    public static void titlu(final String t) { titluT = t; pe(new Runnable() { public void run() { titlu.setText(t); } }); }
    public static void stare(final String t) { stareT = t; pe(new Runnable() { public void run() { stare.setText(t); } }); }

    public static void spune(final int culoare, final String cine, final String ce) {
        pe(new Runnable() { public void run() {
            if (chat.length() > 0) chat.append("\n\n");
            int a = chat.length();
            if (cine != null && !cine.isEmpty()) {
                chat.append(cine);
                chat.setSpan(new ForegroundColorSpan(culoare), a, chat.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
                chat.setSpan(new StyleSpan(Typeface.BOLD), a, chat.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
                chat.append(ce);
            } else {
                chat.append(ce);
                chat.setSpan(new ForegroundColorSpan(culoare), a, chat.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
            }
            if (chat.length() > 60000) chat.delete(0, chat.length() - 50000);
            log.setText(chat);
            scroll.post(new Runnable() { public void run() { scroll.fullScroll(View.FOCUS_DOWN); } });
        }});
    }

    public static void buton(int nr, String t, int f, int s) {
        if (nr < 1 || nr >= 20 || (nr > 8 && nr < 11)) return;
        eticheta[nr] = t; fond[nr] = f; scris[nr] = s;
        pe(new Runnable() { public void run() { butoane(); } });
    }

    public static int apasat() { return apasat; }

    public static String intrare() {
        String t = intrare;
        intrare = "";
        pe(new Runnable() { public void run() { casuta.setText(""); } });
        return t;
    }

    public static void alege() {
        pe(new Runnable() { public void run() {
            Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            i.addCategory(Intent.CATEGORY_OPENABLE);
            i.setType("*/*");
            try { act.startActivityForResult(i, ALEGE); }
            catch (Throwable e) { spune(DIM, "", "Telefonul nu mă lasă să aleg un fișier."); }
        }});
    }

    public static String dosar() { return act.getFilesDir().getAbsolutePath(); }

    /** un fisier din assets (dosarul X/ de langa X.Mod), copiat o data pe versiune in dosarul aplicatiei */
    public static String resursa(String nume) {
        try {
            File d = new File(act.getFilesDir(), "resurse");
            String ver = "" + act.getPackageManager().getPackageInfo(act.getPackageName(), 0).lastUpdateTime;
            File semn = new File(d, ".versiune");
            String era = "";
            if (semn.exists()) { BufferedReader r = new BufferedReader(new FileReader(semn)); era = r.readLine(); r.close(); }
            if (!ver.equals(era)) {
                File[] l = d.listFiles();
                if (l != null) for (File x : l) x.delete();
                d.mkdirs();
                Writer w = new FileWriter(semn); w.write(ver); w.close();
            }
            File f = new File(d, nume);
            if (!f.isFile()) {
                InputStream i = act.getAssets().open(nume);
                File tmp = new File(d, nume + ".tmp");
                tmp.getParentFile().mkdirs();
                OutputStream o = new FileOutputStream(tmp);
                byte[] b = new byte[1 << 16];
                int k;
                while ((k = i.read(b)) > 0) o.write(b, 0, k);
                o.close(); i.close();
                tmp.renameTo(f);
            }
            return f.getAbsolutePath();
        } catch (Throwable t) { return null; }
    }

    public static boolean adauga(String cale, byte[] b, int n) {
        try {
            File f = new File(cale);
            if (f.getParentFile() != null) f.getParentFile().mkdirs();     // v23: dosarul (Download/macinate) il face aici
            OutputStream o = new FileOutputStream(f, true); o.write(b, 0, n); o.close(); return true;
        }
        catch (IOException e) { return false; }
    }

    public static int ms() { return (int) (System.currentTimeMillis() - t0); }

    // ------------------------------------------------------------------ v22: reteaua, Download, ceasul

    public static int aduce(String adresa, String cale) { return Plasa.aduce(adresa, cale); }

    public static String descarcari() {
        if (android.os.Build.VERSION.SDK_INT >= 23
                && act.checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            pe(new Runnable() { public void run() {
                act.requestPermissions(new String[] {android.Manifest.permission.READ_EXTERNAL_STORAGE,
                    android.Manifest.permission.WRITE_EXTERNAL_STORAGE}, 7);
            }});
            return null;
        }
        File d = android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS);
        return d == null ? null : d.getAbsolutePath();
    }

    /** Tic* la fiecare ms, pe firul Oberon, dupa ce s-a terminat cel de dinainte; 0 = oprit */
    public static void ceas(int ms) {
        ceasMs = ms;
        if (ms > 0 && !ticAsteapta) programeaza();
    }

    static void programeaza() {
        ticAsteapta = true;
        h.postDelayed(new Runnable() { public void run() {
            lucreaza(new Runnable() { public void run() {
                ticAsteapta = false;
                if (ceasMs > 0) cheama(tic);
                if (ceasMs > 0 && !ticAsteapta) programeaza();
            }});
        }}, Math.max(50, ceasMs));
    }
    public static void tine(String k, String v) { pref().edit().putString("o." + k, v).apply(); }
    public static String setare(String k) { return pref().getString("o." + k, ""); }
}
