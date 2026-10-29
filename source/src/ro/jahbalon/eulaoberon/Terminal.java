package ro.jahbalon.eulaoberon;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import com.termux.terminal.TerminalColors;
import com.termux.terminal.TerminalEmulator;
import com.termux.terminal.TerminalSession;
import com.termux.terminal.TerminalSessionClient;
import com.termux.view.TerminalView;
import com.termux.view.TerminalViewClient;

import java.io.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Properties;

/**
 * Terminalul Eulei: un shell adevarat (sh-ul Android-ului, intr-un pseudo-terminal deschis de eulapty), violet cu auriu.
 * Emulatorul de terminal e cel din Termux (Apache 2.0, din Android-Terminal-Emulator al lui Jack Palevich).
 * Uneltele ei sunt in PATH: oberonc, dx, ob (compileaza si ruleaza), edit, eula.
 */
public class Terminal extends Activity implements TerminalSessionClient, TerminalViewClient {
    static final int VIOLET = 0xFF16042A, VIOLET2 = 0xFF240A42, VIOLET3 = 0xFF3A1366, AUR = 0xFFC9A85E, AUR2 = 0xFFD6BF8A;
    static final String VERSIUNE_UNELTE = "4";

    /** sesiunea traieste cat traieste procesul aplicatiei, nu doar cat ecranul */
    static TerminalSession sesiune;

    TerminalView ecran;
    FrameLayout radacina;
    LinearLayout taste;
    boolean ctrl, alt;
    Button bCtrl, bAlt;
    int marime;

    // editorul
    LinearLayout editor;
    EditText text;
    TextView titluEditor;
    File fisierEditat;
    boolean schimbat;
    long ultimInapoi;

    int dp(float v) { return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, getResources().getDisplayMetrics()); }

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        getWindow().setStatusBarColor(VIOLET);
        getWindow().setNavigationBarColor(VIOLET);

        Properties p = new Properties();
        p.put("background", "#16042a");
        p.put("foreground", "#c9a85e");   // aur stins, ca foita veche
        p.put("cursor", "#e0c890");
        p.put("color0", "#0e0219");       // negru -> violet foarte inchis
        p.put("color4", "#8fa8ff");       // albastrul se vede pe violet
        p.put("color5", "#e59bff");
        p.put("color8", "#7a5a9a");
        p.put("color12", "#b3c4ff");
        // culorile tale, daca vrei altele: ~/.culori, de ex. foreground=#d4af37 (fundalul ramane violet daca nu-l pui)
        File fc = new File(new File(getFilesDir(), "home"), ".culori");   // aceeasi cale si in sistemul Oberon: ~/.culori
        if (fc.exists()) {
            try {
                Properties t = new Properties();
                Reader r = new InputStreamReader(new FileInputStream(fc), "UTF-8");
                t.load(r);
                r.close();
                for (String k : t.stringPropertyNames()) p.put(k.trim(), t.getProperty(k).trim());
            } catch (Exception e) { /* raman culorile mele */ }
        }
        try { TerminalColors.COLOR_SCHEME.updateWith(p); }
        catch (IllegalArgumentException e) { p.clear(); p.put("background", "#16042a"); p.put("foreground", "#c9a85e"); TerminalColors.COLOR_SCHEME.updateWith(p); }

        radacina = new FrameLayout(this);
        radacina.setBackgroundColor(VIOLET);
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);

        ecran = new TerminalView(this, null);
        ecran.setTerminalViewClient(this);
        ecran.setBackgroundColor(VIOLET);
        ecran.setFocusable(true);
        ecran.setFocusableInTouchMode(true);
        ecran.setKeepScreenOn(true);
        marime = getSharedPreferences("eulaoberon", 0).getInt("terminal", dp(13));
        ecran.setTextSize(marime);
        ecran.setTypeface(Typeface.MONOSPACE);
        col.addView(ecran, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        HorizontalScrollView hs = new HorizontalScrollView(this);
        hs.setHorizontalScrollBarEnabled(false);
        hs.setBackgroundColor(VIOLET2);
        taste = new LinearLayout(this);
        hs.addView(taste);
        tasta("A+", (String) null);
        tasta("A−", (String) null);
        tasta("LIPEȘTE", (String) null);
        tasta("ESC", KeyEvent.KEYCODE_ESCAPE);
        tasta("TAB", KeyEvent.KEYCODE_TAB);
        bCtrl = tasta("CTRL", null);
        bAlt = tasta("ALT", null);
        tasta("←", KeyEvent.KEYCODE_DPAD_LEFT);
        tasta("↓", KeyEvent.KEYCODE_DPAD_DOWN);
        tasta("↑", KeyEvent.KEYCODE_DPAD_UP);
        tasta("→", KeyEvent.KEYCODE_DPAD_RIGHT);
        tasta("-", "-");
        tasta("/", "/");
        tasta("|", "|");
        tasta("~", "~");
        tasta("HOME", KeyEvent.KEYCODE_MOVE_HOME);
        tasta("END", KeyEvent.KEYCODE_MOVE_END);
        tasta("EULA", null);
        col.addView(hs, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(46)));
        radacina.addView(col);
        faEditor();
        setContentView(radacina);

        TerminalEmulator.EULA = new TerminalEmulator.Eula() {
            public void comanda(final String t) { runOnUiThread(new Runnable() { public void run() { comandaShell(t); } }); }
        };
        if (sesiune == null || !sesiune.isRunning()) sesiune = sesiuneNoua();
        sesiune.updateTerminalSessionClient(this);
        ecran.attachSession(sesiune);
        ecran.requestFocus();
    }

    @Override protected void onResume() {
        super.onResume();
        ecran.onScreenUpdated();
    }

    // ------------------------------------------------------------------ shell-ul

    /** shell-ul Eulei e un program Oberon (sistem/Shell.Mod) rulat de dalvikvm intr-un pseudo-terminal */
    TerminalSession sesiuneNoua() {
        File home = new File(getFilesDir(), "home");
        File sistem = new File(getFilesDir(), "sistem");
        File tmp = new File(getCacheDir(), "tmp");
        home.mkdirs(); sistem.mkdirs(); tmp.mkdirs();
        // ce a ramas de la versiunile cu shell Android si cu pachete Termux
        for (String v : new String[] {"usr", "eula", "termux"}) { File x = new File(getFilesDir(), v); if (x.exists()) stergeFaraLegaturi(x); }
        for (String v : new String[] {".mkshrc", ".eula-bashrc", ".hushlogin", ".am-salutat", ".am-salutat-pachete"}) new File(home, v).delete();
        File brc = new File(home, ".bashrc");
        if (brc.exists() && Rulator.citeste(brc).trim().equals("[ -f ~/.eula-bashrc ] && . ~/.eula-bashrc")) brc.delete();
        String eroare = null;
        File u = null;
        try { u = Rulare.unelte(this); } catch (Throwable t) { eroare = t.toString(); }
        try { surse(new File(home, "sistem"), home); } catch (IOException e) { /* nu e grav */ }
        TerminalSession.PTY = new File(getApplicationInfo().nativeLibraryDir, "libeulapty.so").getAbsolutePath();

        List<String> env = new ArrayList<String>();
        for (Map.Entry<String, String> e : System.getenv().entrySet()) {
            String k = e.getKey();
            if (k.equals("HOME") || k.equals("TMPDIR") || k.equals("TERM") || k.startsWith("LD_")) continue;
            env.add(k + "=" + e.getValue());
        }
        env.add("HOME=" + home.getAbsolutePath());
        env.add("TMPDIR=" + tmp.getAbsolutePath());
        env.add("TERM=xterm-256color");
        env.add("LANG=ro_RO.UTF-8");
        env.add("EULA_UNELTE=" + (u == null ? "" : u.getAbsolutePath()));
        env.add("EULA_SISTEM=" + sistem.getAbsolutePath());
        env.add("EULA_APK=" + getApplicationInfo().sourceDir);   // v29: apk ... eula ia bucatile Eulei de aici
        Inferno.adaugaMediu(env, this);
        new Thread(new Runnable() { public void run() {      // radacina lui Inferno, o data pe versiune, in spate
            try { Inferno.pregateste(Terminal.this); } catch (Throwable t) { /* o incerc din nou la nevoie */ }
        }}, "inferno-radacina").start();
        if (u == null || !new File(u, "sistem.jar").exists()) {
            String er = eroare == null ? "lipseste sistem.jar in " + u : eroare.replace('\n', ' ');
            env.add("EULA_EROARE=" + er);
            env.add("PS1=rezerva$ ");
            try { scrie(new File(home, "eroare-sistem.txt"), er + "\n"); } catch (IOException e) { /* nimic */ }
            return new TerminalSession("/system/bin/sh", home.getAbsolutePath(), new String[] {"-c",
                "echo \"Sistemul Eulei n-a pornit: $EULA_EROARE\"; echo 'Shell-ul Android, ca rezerva:'; exec /system/bin/sh -i"},
                env.toArray(new String[0]), 3000, this);
        }
        // ca Termux (termux-tools/dalvikvm): pe Android 10+ masina Java e in /apex, si vrea un ANDROID_DATA al ei
        File ad = new File(getFilesDir(), "android");
        new File(ad, "dalvik-cache").mkdirs();
        for (int i = env.size() - 1; i >= 0; i--) if (env.get(i).startsWith("ANDROID_DATA=")) env.remove(i);
        env.add("ANDROID_DATA=" + ad.getAbsolutePath());
        String dvm = "/system/bin/dalvikvm";
        for (String c : new String[] {"/apex/com.android.art/bin/dalvikvm", "/apex/com.android.runtime/bin/dalvikvm", "/system/bin/dalvikvm"})
            if (new File(c).exists()) { dvm = c; break; }
        // ca dx.jar in Termux (chmod -w): Android 14 nu incarca cod dex dintr-un fisier in care se poate scrie
        for (String j : new String[] {"sistem.jar", "compilator.jar", "dx.jar", "rt.jar", "aplicatie.jar"}) new File(u, j).setReadOnly();
        pornitJava = System.currentTimeMillis();
        return new TerminalSession(dvm, home.getAbsolutePath(), new String[] {
            "-Xusejit:true", "-Xnoimage-dex2oat", "-Xmx384m", "-Djava.io.tmpdir=" + tmp.getAbsolutePath(),
            "-cp", new File(u, "sistem.jar").getAbsolutePath(), "EulaSistem"},
            env.toArray(new String[0]), 3000, this);
    }

    /** exemplul din casa ta e chiar unul trimis de mine intr-o versiune mai veche (nu l-ai schimbat)? */
    boolean eVechi(String nume, String continut) {
        try {
            String[] l = getAssets().list("exemple-vechi");
            if (l != null) for (String v : l) {
                if (!v.startsWith(nume + ".")) continue;
                InputStream i = getAssets().open("exemple-vechi/" + v);
                ByteArrayOutputStream b = new ByteArrayOutputStream();
                byte[] buf = new byte[8192];
                int k;
                while ((k = i.read(buf)) > 0) b.write(buf, 0, k);
                i.close();
                if (b.toString("UTF-8").equals(continut)) return true;
            }
        } catch (IOException e) { /* nu */ }
        return false;
    }

    /** sterge un dosar fara sa intre pe legaturi (pachetele Termux aveau legaturi spre alte locuri) */
    static void stergeFaraLegaturi(File f) {
        boolean leg;
        try { leg = !f.getCanonicalPath().equals(new File(f.getAbsoluteFile().getParentFile().getCanonicalFile(), f.getName()).getPath()); }
        catch (Exception e) { leg = true; }
        if (!leg && f.isDirectory()) { File[] k = f.listFiles(); if (k != null) for (File x : k) stergeFaraLegaturi(x); }
        f.delete();
    }

    /** sursele modulelor sistemului (Shell, Fisiere, Net, Module, punțile) in ~/sistem, de citit; la fiecare versiune */
    void surse(File d, File home) throws IOException {
        File semn = new File(d, ".versiune");
        String ver;
        try { ver = "" + getPackageManager().getPackageInfo(getPackageName(), 0).lastUpdateTime; } catch (Exception e) { ver = "?"; }
        if (semn.exists() && Rulator.citeste(semn).trim().equals(ver)) return;
        d.mkdirs();
        String[] l = getAssets().list("sistem");
        if (l != null) for (String f : l) {
            InputStream i = getAssets().open("sistem/" + f);
            OutputStream o = new FileOutputStream(new File(d, f));
            byte[] b = new byte[16384];
            int k;
            while ((k = i.read(b)) > 0) o.write(b, 0, k);
            o.close(); i.close();
        }
        scrie(semn, ver);
        // exemplele (Salut, Vopsea, Busola) in casa ta, doar daca nu le ai deja (nu-ti stric ce ai schimbat)
        String[] ex = getAssets().list("exemple");
        if (ex != null) for (String f : ex) {
            String[] sub = getAssets().list("exemple/" + f);
            if (sub != null && sub.length > 0) {          // v21: dosarul unui exemplu (Eula7/: datele ei), la fiecare versiune
                File dd = new File(home, f);
                dd.mkdirs();
                for (String x : sub) {
                    InputStream i = getAssets().open("exemple/" + f + "/" + x);
                    OutputStream o = new FileOutputStream(new File(dd, x));
                    byte[] bb = new byte[65536];
                    int k;
                    while ((k = i.read(bb)) > 0) o.write(bb, 0, k);
                    o.close(); i.close();
                }
                continue;
            }
            File in = new File(home, f);
            if (in.exists() && !eVechi(f, Rulator.citeste(in))) continue;   // al tau, schimbat de tine: nu-l ating
            InputStream i = getAssets().open("exemple/" + f);
            OutputStream o = new FileOutputStream(in);
            byte[] bb = new byte[16384];
            int k;
            while ((k = i.read(bb)) > 0) o.write(bb, 0, k);
            o.close(); i.close();
        }
    }

    static void scrie(File f, String s) throws IOException {
        Writer w = new OutputStreamWriter(new FileOutputStream(f), "UTF-8");
        w.write(s);
        w.close();
        f.setExecutable(true, true);
    }

    void comandaShell(String t) {
        if (t.equals("eula")) { deschideEula(); return; }
        if (t.startsWith("edit;")) { deschideEditor(new File(t.substring(5))); return; }
        if (t.equals("senzor;busola")) { busola(true); return; }
        if (t.startsWith("instaleaza;")) { instaleaza(new File(t.substring(11))); return; }
        if (t.equals("acces;fisiere")) { cereAcces(); return; }
        if (t.equals("senzor;oprit")) { busola(false); }
        if (t.startsWith("inferno;")) {                 // ecranul lui Inferno: biroul (wm) sau Charon
            Intent i = new Intent(this, EcranInferno.class);
            i.putExtra("program", t.substring(8));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(i);
        }
    }

    // ------------------------------------------------------------------ senzorii (pentru modulul Senzor)

    android.hardware.SensorEventListener ascultator;
    final float[] rot = new float[9], ori = new float[3], grav = new float[3], mag = new float[3];
    boolean areGrav, areMag;
    long ultimScris;

    File fisierBusola() { return new File(new File(getFilesDir(), "sistem"), "senzor-busola"); }

    void scrieBusola(int a) {
        try {
            File f = fisierBusola(), t = new File(f.getPath() + ".t");
            scrie(t, a + "\n");
            t.renameTo(f);
        } catch (IOException e) { /* nimic */ }
    }

    void busola(boolean porneste) {
        android.hardware.SensorManager sm = (android.hardware.SensorManager) getSystemService(Context.SENSOR_SERVICE);
        if (ascultator != null) { sm.unregisterListener(ascultator); ascultator = null; }
        if (!porneste) { fisierBusola().delete(); return; }
        android.hardware.Sensor rv = sm.getDefaultSensor(android.hardware.Sensor.TYPE_ROTATION_VECTOR);
        final android.hardware.Sensor acc = sm.getDefaultSensor(android.hardware.Sensor.TYPE_ACCELEROMETER);
        android.hardware.Sensor mg = sm.getDefaultSensor(android.hardware.Sensor.TYPE_MAGNETIC_FIELD);
        if (rv == null && (acc == null || mg == null)) { scrieBusola(-2); return; }
        scrieBusola(-1);
        areGrav = areMag = false;
        ascultator = new android.hardware.SensorEventListener() {
            public void onSensorChanged(android.hardware.SensorEvent e) {
                int tip = e.sensor.getType();
                if (tip == android.hardware.Sensor.TYPE_ROTATION_VECTOR) {
                    android.hardware.SensorManager.getRotationMatrixFromVector(rot, e.values);
                } else {
                    if (tip == android.hardware.Sensor.TYPE_ACCELEROMETER) { System.arraycopy(e.values, 0, grav, 0, 3); areGrav = true; }
                    else { System.arraycopy(e.values, 0, mag, 0, 3); areMag = true; }
                    if (!areGrav || !areMag || !android.hardware.SensorManager.getRotationMatrix(rot, null, grav, mag)) return;
                }
                long acum = System.currentTimeMillis();
                if (acum - ultimScris < 80) return;
                ultimScris = acum;
                android.hardware.SensorManager.getOrientation(rot, ori);
                int a = (int) Math.round(Math.toDegrees(ori[0]));
                scrieBusola((a + 360) % 360);
            }
            public void onAccuracyChanged(android.hardware.Sensor s, int acc) {}
        };
        if (rv != null) sm.registerListener(ascultator, rv, android.hardware.SensorManager.SENSOR_DELAY_UI);
        else {
            sm.registerListener(ascultator, acc, android.hardware.SensorManager.SENSOR_DELAY_UI);
            sm.registerListener(ascultator, mg, android.hardware.SensorManager.SENSOR_DELAY_UI);
        }
    }

    @Override protected void onDestroy() {
        if (ascultator != null) busola(false);
        super.onDestroy();
    }

    /** APK-urile facute cu Aplicatie.Fa: le dau instalatorului Android-ului, prin Furnizor */
    void instaleaza(File apk) {
        try {
            if (!apk.getParentFile().getCanonicalPath().equals(new File(getFilesDir(), "home").getCanonicalPath())) {
                Toast.makeText(this, "Pune APK-ul in casa ta (~) ca sa-l pot instala.", Toast.LENGTH_LONG).show();
                return;
            }
            Intent i = new Intent(Intent.ACTION_VIEW);
            i.setDataAndType(Furnizor.uri(apk), "application/vnd.android.package-archive");
            i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(i);
        } catch (Exception e) {
            Toast.makeText(this, "Instalatorul n-a pornit: " + e, Toast.LENGTH_LONG).show();
        }
    }

    /** voie la fisierele telefonului (Download), pentru comanda html: o data, la cerere */
    void cereAcces() {
        if (android.os.Build.VERSION.SDK_INT >= 23
                && checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[] {android.Manifest.permission.READ_EXTERNAL_STORAGE,
                android.Manifest.permission.WRITE_EXTERNAL_STORAGE}, 7);
        } else {
            Toast.makeText(this, "Eula are deja voie la fisiere. Daca tot nu vede Download, inchide si deschide terminalul.", Toast.LENGTH_LONG).show();
        }
    }

    void deschideEula() {
        Intent i = new Intent(this, EulaOberon.class);
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(i);
    }

    // ------------------------------------------------------------------ tastele de jos

    /** o tasta speciala: trece prin KeyHandler-ul emulatorului, ca sa respecte modurile (sagetile in vi etc.) */
    Button tasta(final String eticheta, final int cod) {
        Button b = tasta(eticheta, (String) null);
        b.setOnClickListener(new View.OnClickListener() { public void onClick(View v) {
            if (sesiune == null) return;
            int mod = (ctrl ? com.termux.terminal.KeyHandler.KEYMOD_CTRL : 0) | (alt ? com.termux.terminal.KeyHandler.KEYMOD_ALT : 0);
            ctrl = alt = false; aprinde();
            ecran.handleKeyCode(cod, mod);
        }});
        return b;
    }

    Button tasta(final String eticheta, final String trimite) {
        final Button b = new Button(this);
        b.setText(eticheta);
        b.setAllCaps(false);
        b.setTextColor(AUR);
        b.setTextSize(14);
        b.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        b.setBackgroundColor(VIOLET2);
        b.setPadding(dp(10), 0, dp(10), 0);
        b.setMinWidth(dp(46));
        b.setMinimumWidth(dp(46));
        b.setOnClickListener(new View.OnClickListener() { public void onClick(View v) {
            if (eticheta.equals("CTRL")) { ctrl = !ctrl; aprinde(); return; }
            if (eticheta.equals("ALT")) { alt = !alt; aprinde(); return; }
            if (eticheta.equals("A−")) { marime(-1); return; }
            if (eticheta.equals("A+")) { marime(+1); return; }
            if (eticheta.equals("EULA")) { deschideEula(); return; }
            if (eticheta.equals("LIPEȘTE")) { onPasteTextFromClipboard(sesiune); return; }
            if (sesiune == null) return;
            if (trimite.length() == 1 && (ctrl || alt)) {
                ecran.inputCodePoint(0, trimite.charAt(0), ctrl, alt);
                ctrl = alt = false; aprinde();
            } else sesiune.write(trimite);
        }});
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.MATCH_PARENT);
        lp.setMargins(dp(1), dp(3), dp(1), dp(3));
        taste.addView(b, lp);
        return b;
    }

    void aprinde() {
        bCtrl.setBackgroundColor(ctrl ? AUR : VIOLET2); bCtrl.setTextColor(ctrl ? VIOLET : AUR);
        bAlt.setBackgroundColor(alt ? AUR : VIOLET2); bAlt.setTextColor(alt ? VIOLET : AUR);
    }

    void marime(int d) {
        marime = Math.max(dp(7), Math.min(dp(28), marime + d * dp(1)));
        ecran.setTextSize(marime);
        getSharedPreferences("eulaoberon", 0).edit().putInt("terminal", marime).apply();
    }

    // ------------------------------------------------------------------ editorul

    void faEditor() {
        editor = new LinearLayout(this);
        editor.setOrientation(LinearLayout.VERTICAL);
        editor.setBackgroundColor(VIOLET);
        editor.setVisibility(View.GONE);
        editor.setClickable(true);
        titluEditor = new TextView(this);
        titluEditor.setTextColor(AUR2);
        titluEditor.setTextSize(13);
        titluEditor.setPadding(dp(12), dp(8), dp(12), dp(4));
        editor.addView(titluEditor);
        text = new EditText(this);
        text.setTypeface(Typeface.MONOSPACE);
        text.setTextColor(AUR);
        text.setHighlightColor(VIOLET3);
        text.setBackgroundColor(0xFF1C0634);
        text.setGravity(Gravity.TOP | Gravity.START);
        text.setTextSize(15);
        text.setHorizontallyScrolling(true);
        text.setPadding(dp(12), dp(10), dp(12), dp(10));
        text.setInputType(EditorInfo.TYPE_CLASS_TEXT | EditorInfo.TYPE_TEXT_FLAG_MULTI_LINE | EditorInfo.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        text.addTextChangedListener(new TextWatcher() {
            public void beforeTextChanged(CharSequence s, int a, int b, int c) {}
            public void onTextChanged(CharSequence s, int a, int b, int c) {}
            public void afterTextChanged(Editable e) { schimbat = true; }
        });
        editor.addView(text, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        LinearLayout r = new LinearLayout(this);
        r.addView(butonEditor("Salvează", new View.OnClickListener() { public void onClick(View v) { salveaza(); } }), greutate());
        r.addView(butonEditor("Rulează", new View.OnClickListener() { public void onClick(View v) {
            if (salveaza()) { inchideEditor(); sesiune.write("ruleaza \"" + fisierEditat.getAbsolutePath() + "\"\r"); }
        } }), greutate());
        r.addView(butonEditor("Tab", new View.OnClickListener() { public void onClick(View v) {
            text.getText().replace(Math.min(text.getSelectionStart(), text.getSelectionEnd()), Math.max(text.getSelectionStart(), text.getSelectionEnd()), "  ");
        } }), greutate());
        r.addView(butonEditor("Închide", new View.OnClickListener() { public void onClick(View v) { inapoiDinEditor(); } }), greutate());
        editor.addView(r, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(50)));
        radacina.addView(editor, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
    }

    LinearLayout.LayoutParams greutate() {
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1);
        p.setMargins(dp(2), dp(4), dp(2), dp(4));
        return p;
    }

    Button butonEditor(String t, View.OnClickListener l) {
        Button b = new Button(this);
        b.setText(t);
        b.setAllCaps(false);
        b.setTextColor(VIOLET);
        b.setTypeface(Typeface.DEFAULT_BOLD);
        b.setBackgroundColor(AUR);
        b.setTextSize(14);
        b.setPadding(0, 0, 0, 0);
        b.setOnClickListener(l);
        return b;
    }

    void deschideEditor(File f) {
        fisierEditat = f;
        String s = "";
        if (f.exists()) {
            if (f.length() > 2000000) { sesiune.write("echo 'fișierul e prea mare pentru editor'\r"); return; }
            s = Rulator.citeste(f);
        }
        text.setText(s);
        schimbat = false;
        titluEditor.setText(f.getAbsolutePath().replace(new File(getFilesDir(), "home").getAbsolutePath(), "~") + (f.exists() ? "" : "  (nou)"));
        editor.setVisibility(View.VISIBLE);
        text.requestFocus();
        ((InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE)).showSoftInput(text, 0);
    }

    boolean salveaza() {
        try {
            File d = fisierEditat.getParentFile();
            if (d != null) d.mkdirs();
            Writer w = new OutputStreamWriter(new FileOutputStream(fisierEditat), "UTF-8");
            w.write(text.getText().toString());
            w.close();
            schimbat = false;
            Toast.makeText(this, "Salvat: " + fisierEditat.getName(), Toast.LENGTH_SHORT).show();
            return true;
        } catch (IOException e) {
            Toast.makeText(this, "Nu pot salva: " + e.getMessage(), Toast.LENGTH_LONG).show();
            return false;
        }
    }

    void inapoiDinEditor() {
        if (schimbat && System.currentTimeMillis() - ultimInapoi > 2500) {
            ultimInapoi = System.currentTimeMillis();
            Toast.makeText(this, "Ai schimbări nesalvate. Apasă din nou ca să ieși fără să salvezi.", Toast.LENGTH_SHORT).show();
            return;
        }
        inchideEditor();
    }

    void inchideEditor() {
        editor.setVisibility(View.GONE);
        ((InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(text.getWindowToken(), 0);
        ecran.requestFocus();
    }

    @Override public void onBackPressed() {
        if (editor.getVisibility() == View.VISIBLE) { inapoiDinEditor(); return; }
        // v30: in aplicatia unita (apk X.Mod "Nume" eula), Inapoi te duce in aplicatia ta (Cubicum); terminalul,
        // cu Inferno si mount-ul lui, ramane pornit in spate
        if (!getPackageName().equals("ro.jahbalon.eulaoberon")) {
            android.content.Intent i = getPackageManager().getLaunchIntentForPackage(getPackageName());
            if (i != null) {
                i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK);
                try { startActivity(i); return; } catch (Exception e) { /* mai jos */ }
            }
        }
        super.onBackPressed();
    }

    // ------------------------------------------------------------------ TerminalSessionClient

    public void onTextChanged(TerminalSession s) { ecran.onScreenUpdated(); }
    public void onTitleChanged(TerminalSession s) {}
    long pornitJava;

    /** daca masina Java a cazut (semnal), arat ce a scris ea in jurnalul Android-ului: altfel n-am sti de ce */
    public void onSessionFinished(final TerminalSession s) {
        if (repornesc) {                       // l-am oprit noi (Ctrl+C): pornesc altul, fara jurnal
            repornesc = false;
            spune("\r\n(comanda nu s-a oprit singura; am repornit sistemul, biblioteca ta e intacta)\r\n");
            final TerminalSession v = s;
            ecran.postDelayed(new Runnable() { public void run() {
                if (sesiune != v) return;
                sesiune = sesiuneNoua();
                sesiune.updateTerminalSessionClient(Terminal.this);
                ecran.attachSession(sesiune);
            }}, 600);
            return;
        }
        int st = s.getExitStatus();
        if (st >= 0 || pornitJava == 0 || st == -2 || st == -9 || st == -15) return;   // doar caderile adevarate
        final long de = pornitJava;
        new Thread(new Runnable() { public void run() {
            StringBuilder r = new StringBuilder();
            try {
                Process p = new ProcessBuilder("logcat", "-d", "-v", "brief", "-t", "400").redirectErrorStream(true).start();
                BufferedReader b = new BufferedReader(new InputStreamReader(p.getInputStream(), "UTF-8"));
                List<String> l = new ArrayList<String>();
                String x;
                while ((x = b.readLine()) != null)
                    if (x.startsWith("F/") || x.startsWith("E/") || x.contains("dalvikvm") || x.contains("art")) l.add(x);
                p.waitFor();
                for (int i = Math.max(0, l.size() - 14); i < l.size(); i++) r.append(l.get(i)).append("\r\n");
            } catch (Exception e) { r.append("(nu pot citi jurnalul: ").append(e).append(")\r\n"); }
            final String t = "\r\n--- jurnalul Android (pentru Claude) ---\r\n" + (r.length() == 0 ? "(gol)\r\n" : r.toString())
                + "--- sfârșit; trimite o captură ---\r\n";
            runOnUiThread(new Runnable() { public void run() {
                if (sesiune != s || s.getEmulator() == null) return;
                byte[] by;
                try { by = t.getBytes("UTF-8"); } catch (UnsupportedEncodingException e) { return; }
                s.getEmulator().append(by, by.length);
                ecran.onScreenUpdated();
            }});
        }}).start();
    }
    public void onCopyTextToClipboard(TerminalSession s, String t) {
        ClipboardManager c = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        if (c != null) c.setPrimaryClip(ClipData.newPlainText("", t));
    }
    public void onPasteTextFromClipboard(TerminalSession s) {
        ClipboardManager c = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        if (c == null || !c.hasPrimaryClip() || c.getPrimaryClip().getItemCount() == 0) return;
        CharSequence t = c.getPrimaryClip().getItemAt(0).coerceToText(this);
        if (t != null && sesiune != null && sesiune.getEmulator() != null) sesiune.getEmulator().paste(t.toString());
    }
    public void onBell(TerminalSession s) {}
    public void onColorsChanged(TerminalSession s) {}
    public void onTerminalCursorStateChange(boolean state) {}
    public void setTerminalShellPid(TerminalSession s, int pid) {}
    public Integer getTerminalCursorStyle() { return null; }
    public void logError(String tag, String message) {}
    public void logWarn(String tag, String message) {}
    public void logInfo(String tag, String message) {}
    public void logDebug(String tag, String message) {}
    public void logVerbose(String tag, String message) {}
    public void logStackTraceWithMessage(String tag, String message, Exception e) {}
    public void logStackTrace(String tag, Exception e) {}

    // ------------------------------------------------------------------ TerminalViewClient

    public float onScale(float scale) {
        if (scale < 0.9f || scale > 1.1f) { marime(scale > 1 ? +1 : -1); return 1.0f; }
        return scale;
    }
    public void onSingleTapUp(MotionEvent e) {
        if (sesiune != null && !sesiune.isRunning()) return;
        ecran.requestFocus();
        ((InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE)).showSoftInput(ecran, InputMethodManager.SHOW_IMPLICIT);
    }
    public boolean shouldBackButtonBeMappedToEscape() { return false; }
    public boolean shouldEnforceCharBasedInput() { return true; }
    public boolean shouldUseCtrlSpaceWorkaround() { return false; }
    public boolean isTerminalViewSelected() { return true; }
    public void copyModeChanged(boolean copyMode) {}
    public boolean onKeyDown(int keyCode, KeyEvent e, TerminalSession s) {
        if (keyCode == KeyEvent.KEYCODE_ENTER && s != null && !s.isRunning()) {   // shell-ul s-a inchis: unul nou
            sesiune = sesiuneNoua();
            ecran.attachSession(sesiune);
            return true;
        }
        return false;
    }
    public boolean onKeyUp(int keyCode, KeyEvent e) { return false; }
    public boolean onLongPress(MotionEvent event) { return false; }
    public boolean readControlKey() { boolean c = ctrl; if (c) { ctrl = false; aprinde(); } return c; }
    public boolean readAltKey() { boolean a = alt; if (a) { alt = false; aprinde(); } return a; }
    public boolean readShiftKey() { return false; }
    public boolean readFnKey() { return false; }
    public boolean onCodePoint(int codePoint, boolean ctrlDown, TerminalSession s) {
        if (ctrlDown && (codePoint == 'c' || codePoint == 'C') && pornitJava != 0 && s != null && s.isRunning()) { ctrlC(s); return true; }
        return false;
    }

    /** Ctrl+C in sistemul Oberon: nu omor tot sistemul. Daca ruleaza o comanda, ii cer sa se opreasca (Nucleu.Oprit);
     *  daca nu se opreste in 2 secunde, repornesc sistemul (biblioteca ta ramane, e pe disc). La prompt: sterg randul. */
    void ctrlC(final TerminalSession s) {
        File sis = new File(getFilesDir(), "sistem");
        final File ocupat = new File(sis, "ocupat");
        if (!ocupat.exists()) { s.write("\u0015\r"); return; }     // Ctrl+U: sterge ce era scris, apoi un prompt nou
        try { scrie(new File(sis, "opreste"), ""); } catch (IOException e) { /* nimic */ }
        spune("^C");
        ecran.postDelayed(new Runnable() { public void run() {
            if (!ocupat.exists() || sesiune != s || !s.isRunning()) return;
            ocupat.delete();
            repornesc = true;
            s.finishIfRunning();
        }}, 2000);
    }

    boolean repornesc;

    void spune(final String text) {
        if (sesiune == null || sesiune.getEmulator() == null) return;
        byte[] b;
        try { b = text.getBytes("UTF-8"); } catch (UnsupportedEncodingException e) { return; }
        sesiune.getEmulator().append(b, b.length);
        ecran.onScreenUpdated();
    }
    public void onEmulatorSet() {}
}
