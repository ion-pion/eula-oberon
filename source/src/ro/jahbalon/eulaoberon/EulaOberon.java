package ro.jahbalon.eulaoberon;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.ResultReceiver;
import android.text.SpannableStringBuilder;
import android.text.Spanned;
import android.text.style.BackgroundColorSpan;
import android.text.style.ForegroundColorSpan;
import android.text.style.RelativeSizeSpan;
import android.text.style.StyleSpan;
import android.text.style.TypefaceSpan;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.io.*;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.Charset;
import java.nio.charset.CodingErrorAction;

/**
 * Eula Oberon v2 — pielea de Java. Aici sunt doar ecranul, cele patru butoane si cititul fisierelor de pe telefon.
 * Tot ce inseamna ceva (gramatica, memoria, sorobanul 7D, Opal, Roler, firea) e in modulele Oberon, compilate cu
 * oberonc chiar pe telefon, si se cheama prin Oberon.java.
 */
public class EulaOberon extends Activity {
    static final int BG = 0xFF07130F, PANEL = 0xFF0F201A, ACCENT = 0xFF5EEAD4, GOLD = 0xFFFFC52E, DIM = 0xFF8FB3A8, TEXT = 0xFFEEF6F2,
        COD = 0xFFB9F6CA, CODBG = 0xFF0A2A20;
    static final int IMPORT = 7;
    static final char REC = '\u001E', C0 = '\u0002', C1 = '\u0003';

    TextView log, status;
    Button rulez;
    volatile int pidRulare = 0;
    int rulareNr = 0;
    boolean ruleaza = false;
    static final int RULEAZA = 0xFFFF8A65;
    EditText input;
    ScrollView scroll;
    final SpannableStringBuilder chat = new SpannableStringBuilder();
    float size = 16;
    volatile boolean busy = true, loaded = false, dirty = false;

    File memFile() { return new File(getFilesDir(), "memorie-oberon.txt"); }
    File snapFile() { return new File(getFilesDir(), "index-oberon2.bin"); }

    int dp(float v) { return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, getResources().getDisplayMetrics()); }

    /** firele de lucru au stiva mare: parserul Oberon coboara recursiv, ca la Wirth */
    void fir(Runnable r) { new Thread(null, r, "eula", 64L << 20).start(); }

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        size = getSharedPreferences("eulaoberon", 0).getFloat("size", 16);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(BG);
        root.setPadding(dp(12), dp(10), dp(12), dp(10));

        LinearLayout top = new LinearLayout(this);
        top.setGravity(Gravity.CENTER_VERTICAL);
        TextView title = new TextView(this);
        title.setText("EULA·OBERON");
        title.setTextColor(ACCENT);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        title.setTextSize(22);
        top.addView(title);
        status = new TextView(this);
        status.setTextColor(DIM);
        status.setTextSize(12);
        status.setPadding(dp(10), 0, 0, 0);
        status.setText("pornesc…");
        top.addView(status, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        top.addView(small(">_", new View.OnClickListener() { public void onClick(View v) { startActivity(new Intent(EulaOberon.this, Terminal.class)); } }));
        top.addView(small("A−", new View.OnClickListener() { public void onClick(View v) { text(-1); } }));
        top.addView(small("A+", new View.OnClickListener() { public void onClick(View v) { text(+1); } }));
        root.addView(top);

        scroll = new ScrollView(this);
        scroll.setBackgroundColor(PANEL);
        log = new TextView(this);
        log.setTextColor(TEXT);
        log.setTextSize(size);
        log.setPadding(dp(14), dp(12), dp(14), dp(12));
        log.setTextIsSelectable(true);
        scroll.addView(log);
        LinearLayout.LayoutParams sp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1);
        sp.topMargin = dp(8);
        root.addView(scroll, sp);

        input = new EditText(this);
        input.setHint("Întreabă, sau lipește cod Oberon…");
        input.setHintTextColor(DIM);
        input.setTextColor(TEXT);
        input.setBackgroundColor(PANEL);
        input.setMaxLines(7);
        input.setPadding(dp(14), dp(12), dp(14), dp(12));
        LinearLayout.LayoutParams ip = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        ip.topMargin = dp(8);
        root.addView(input, ip);

        LinearLayout row = new LinearLayout(this);
        row.addView(big("Ask", ACCENT, 0xFF07130F, new View.OnClickListener() { public void onClick(View v) { ask(); } }), weight());
        row.addView(big("Verifică", GOLD, 0xFF07130F, new View.OnClickListener() { public void onClick(View v) { verifica(); } }), weight());
        rulez = big("Rulează", RULEAZA, 0xFF07130F, new View.OnClickListener() { public void onClick(View v) { ruleaza(); } });
        row.addView(rulez, weight());
        row.addView(big("Feed", 0xFF1F6F5C, Color.WHITE, new View.OnClickListener() { public void onClick(View v) { feed(); } }), weight());
        row.addView(big("Importă", 0xFF1C3A31, TEXT, new View.OnClickListener() { public void onClick(View v) { pickImport(); } }), weight());
        LinearLayout.LayoutParams rp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        rp.topMargin = dp(8);
        root.addView(row, rp);
        setContentView(root);

        fir(new Runnable() { public void run() { load(); } });
    }

    LinearLayout.LayoutParams weight() {
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(0, dp(54), 1);
        p.setMargins(dp(2), 0, dp(2), 0);
        return p;
    }

    Button big(String t, int bg, int fg, View.OnClickListener l) {
        Button b = new Button(this);
        b.setText(t);
        b.setAllCaps(false);
        b.setTextSize(13);
        b.setSingleLine(true);
        b.setPadding(0, 0, 0, 0);
        b.setTypeface(Typeface.DEFAULT_BOLD);
        b.setTextColor(fg);
        b.setBackgroundColor(bg);
        b.setOnClickListener(l);
        return b;
    }

    TextView small(String t, View.OnClickListener l) {
        TextView v = new TextView(this);
        v.setText(t);
        v.setTextColor(ACCENT);
        v.setTextSize(19);
        v.setTypeface(Typeface.DEFAULT_BOLD);
        v.setPadding(dp(12), dp(8), dp(12), dp(8));
        v.setOnClickListener(l);
        return v;
    }

    void text(int d) {
        size = Math.max(11, Math.min(30, size + d * 2));
        log.setTextSize(size);
        getSharedPreferences("eulaoberon", 0).edit().putFloat("size", size).apply();
    }

    /** scrie in conversatie; ce e intre \u0002 si \u0003 e cod si iese cu litere de masina de scris */
    void say(final int color, final String who, final String what) {
        runOnUiThread(new Runnable() { public void run() {
            if (chat.length() > 0) chat.append("\n\n");
            int a = chat.length();
            if (who != null) {
                chat.append(who);
                chat.setSpan(new ForegroundColorSpan(color), a, chat.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
                chat.setSpan(new StyleSpan(Typeface.BOLD), a, chat.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
            }
            int start = chat.length();
            int i = 0;
            while (i < what.length()) {
                int c0 = what.indexOf(C0, i);
                if (c0 < 0) { chat.append(what.substring(i)); break; }
                chat.append(what.substring(i, c0));
                int c1 = what.indexOf(C1, c0 + 1);
                if (c1 < 0) c1 = what.length();
                if (chat.length() > 0 && chat.charAt(chat.length() - 1) != '\n') chat.append('\n');
                int s = chat.length();
                chat.append(what.substring(c0 + 1, c1));
                int e = chat.length();
                chat.setSpan(new TypefaceSpan("monospace"), s, e, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
                chat.setSpan(new ForegroundColorSpan(COD), s, e, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
                chat.setSpan(new BackgroundColorSpan(CODBG), s, e, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
                chat.setSpan(new RelativeSizeSpan(0.88f), s, e, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
                i = c1 + 1;
            }
            if (who == null) chat.setSpan(new ForegroundColorSpan(color), start, chat.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
            if (chat.length() > 80000) chat.delete(0, chat.length() - 60000);
            log.setText(chat);
            scroll.post(new Runnable() { public void run() { scroll.fullScroll(View.FOCUS_DOWN); } });
        }});
    }

    void eula(String text) { say(GOLD, "Eula Oberon: ", text); }

    void stat(final String s) { runOnUiThread(new Runnable() { public void run() { status.setText(s); } }); }

    void stat() {
        try { synchronized (Oberon.LOCK) { stat(Oberon.stare()); } } catch (Throwable t) { /* ramane ce era */ }
    }

    static String greseala(Throwable t) {
        StackTraceElement[] st = t.getStackTrace();
        return t + (st.length > 0 ? " (în " + st[0].getClassName() + "." + st[0].getMethodName() + ")" : "");
    }

    // ---------- fisierele (doar citit si scris; intelesul e la Oberon) ----------

    static byte[] readAll(InputStream in) throws IOException {
        ByteArrayOutputStream bo = new ByteArrayOutputStream();
        byte[] buf = new byte[1 << 16];
        int n;
        while ((n = in.read(buf)) > 0) bo.write(buf, 0, n);
        in.close();
        return bo.toByteArray();
    }

    /** UTF-8 daca se poate, altfel Latin-1 (sursele vechi Oberon); fara \r */
    static String text(byte[] b, int from, int to) {
        String s;
        try {
            s = Charset.forName("UTF-8").newDecoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(b, from, to - from)).toString();
        } catch (CharacterCodingException e) {
            try { s = new String(b, from, to - from, "ISO-8859-1"); } catch (UnsupportedEncodingException x) { s = ""; }
        }
        return s.replace("\r\n", "\n").replace('\r', '\n');
    }

    String cheie() {
        long v = 0;
        try { v = getPackageManager().getPackageInfo(getPackageName(), 0).lastUpdateTime; } catch (Exception e) { /* fara */ }
        return v + ":" + memFile().length();
    }

    /** bucatile „\n␞antet\n…”: antetul e calea fisierului sau „timp\tsursa” */
    void citeste(byte[] raw, String ce) throws Exception {
        java.util.List<Integer> cut = new java.util.ArrayList<Integer>();
        if (raw.length > 0 && raw[0] == (byte) REC) cut.add(1);
        for (int p = 0; p + 1 < raw.length; p++) if (raw[p] == '\n' && raw[p + 1] == (byte) REC) cut.add(p + 2);
        int n = cut.size(), last = -1;
        for (int i = 0; i < n; i++) {
            int a = cut.get(i), b = i + 1 < n ? cut.get(i + 1) - 2 : raw.length;
            if (b <= a) continue;
            int nl = a;
            while (nl < b && raw[nl] != '\n') nl++;
            String head = text(raw, a, nl), body = nl < b ? text(raw, nl + 1, b) : "", src = head;
            int tab = head.indexOf('\t');
            if (tab > 0) { try { Long.parseLong(head.substring(0, tab)); src = head.substring(tab + 1); } catch (Exception e) { /* e o cale */ } }
            if (body.trim().isEmpty()) continue;
            synchronized (Oberon.LOCK) { Oberon.mananca(body, src); }
            int pct = (int) (100L * (i + 1) / n);
            if (pct != last) { last = pct; stat(ce + " " + pct + "%"); }
        }
    }

    void load() {
        try {
            synchronized (Oberon.LOCK) {
                Oberon.init();
                Oberon.porneste(getFilesDir().getPath());
                eula(Oberon.salut());
            }
            new File(getFilesDir(), "index-oberon.bin").delete();     // fotografia versiunii in Java nu mai foloseste
            stat("pornire rapidă…");
            String k = cheie();
            boolean rapid;
            synchronized (Oberon.LOCK) { rapid = Oberon.incarcaFoto(snapFile().getPath(), k); }
            if (rapid) say(DIM, null, "(pornire rapidă)");
            else {
                synchronized (Oberon.LOCK) { Oberon.goleste(); }
                stat("citesc raportul lui Wirth…");
                byte[] rb = readAll(getAssets().open("raport.txt"));
                synchronized (Oberon.LOCK) { Oberon.mananca(text(rb, 0, rb.length), "raportul Oberon-07 al lui Wirth"); }
                String[] po = getAssets().list("po");
                int i = 0;
                for (String f : po) {
                    i++;
                    if (!f.endsWith(".Mod")) continue;
                    stat("Project Oberon " + (100 * i / po.length) + "%");
                    byte[] b = readAll(getAssets().open("po/" + f));
                    synchronized (Oberon.LOCK) { Oberon.mananca(text(b, 0, b.length), "Project Oberon 2013/" + f); }
                }
                String[] ea = getAssets().list("eula");               // propriul ei cod: se citeste pe ea insasi
                for (String f : ea) {
                    if (!f.endsWith(".Mod")) continue;
                    byte[] b = readAll(getAssets().open("eula/" + f));
                    synchronized (Oberon.LOCK) { Oberon.mananca(text(b, 0, b.length), "Eula Oberon/" + f); }
                }
                try { citeste(readAll(getAssets().open("hrana-telefon.txt")), "codul de pe telefon"); }
                catch (FileNotFoundException e) { /* scriptul n-a gasit fisiere .Mod */ }
                File f = memFile();
                if (f.exists()) citeste(readAll(new FileInputStream(f)), "ce m-ai învățat");
                saveSnap();
                say(DIM, null, "(am citit și am tăiat toate modulele; data viitoare pornesc repede)");
            }
            loaded = true;
        } catch (Throwable t) {
            eula("Am pățit ceva la pornire: " + greseala(t));
            loaded = true;
        } finally {
            busy = false;
            stat();
        }
    }

    void saveSnap() {
        fir(new Runnable() { public void run() {
            try {
                synchronized (Oberon.LOCK) { Oberon.salveazaFoto(snapFile().getPath(), cheie()); dirty = false; }
            } catch (Throwable t) { /* ramane fotografia veche */ }
        }});
    }

    @Override protected void onPause() {
        super.onPause();
        if (loaded && dirty) saveSnap();
    }

    // ---------- intrebari, verificare, mancare ----------

    void ask() {
        final String q = input.getText().toString().trim();
        if (q.isEmpty() || busy) return;
        boolean cod;
        try { synchronized (Oberon.LOCK) { cod = Oberon.pareCod(q); } } catch (Throwable t) { cod = false; }
        if (cod) { verifica(); return; }                       // cod lipit si trimis cu Ask: il verific
        input.setText("");
        say(ACCENT, "Tu: ", q);
        intreaba(q.equals("?") ? "ce stii sa faci" : q);
    }

    void intreaba(final String q) {
        busy = true;
        stat("se gândește…");
        fir(new Runnable() { public void run() {
            String r, n = "";
            try {
                int fel;
                synchronized (Oberon.LOCK) {
                    fel = Oberon.intreaba(q);
                    r = Oberon.raspuns();
                    n = Oberon.nota();
                }
                if (fel == 3) {                                  // „X este …”: tine minte
                    String src;
                    synchronized (Oberon.LOCK) { src = Oberon.sursaInvatat(); }
                    eat(q, src);
                    synchronized (Oberon.LOCK) { r = Oberon.invatat(q); n = ""; }
                }
            } catch (Throwable t) { r = "Am pățit ceva: " + greseala(t); }
            eula(r);
            if (!n.isEmpty()) say(DIM, null, "(" + n + ")");
            busy = false;
            stat();
        }});
    }

    void verifica() {
        final String t = input.getText().toString();
        if (t.trim().isEmpty() || busy) { if (t.trim().isEmpty()) say(DIM, null, "Lipește cod Oberon în căsuță, apoi apasă Verifică."); return; }
        say(ACCENT, "Tu (de verificat): ", C0 + t + C1);
        busy = true;
        fir(new Runnable() { public void run() {
            String r, n;
            try { synchronized (Oberon.LOCK) { r = Oberon.verifica(t); n = Oberon.nota(); } }
            catch (Throwable x) { r = "Am pățit ceva: " + greseala(x); n = ""; }
            eula(r);
            if (!n.isEmpty()) say(DIM, null, "(" + n + ")");
            busy = false;
        }});
    }

    // ------------------------------------------------------------- Rulează: oberonc + dx + programul, in procesul ":rulare"

    void ruleaza() {
        if (ruleaza) { opreste("L-am oprit, cum ai cerut."); return; }
        final String t = input.getText().toString();
        if (t.trim().isEmpty()) { say(DIM, null, "Scrie sau lipește un modul întreg (MODULE … END Nume.), apoi apasă Rulează."); return; }
        say(ACCENT, "Tu (de rulat): ", C0 + t + C1);
        ruleaza = true;
        rulez.setText("Oprește");
        final int nr = ++rulareNr;
        pidRulare = 0;
        Intent i = new Intent(this, Rulare.class);
        i.putExtra(Rulare.TEXT, t);
        i.putExtra(Rulare.RR, new ResultReceiver(new Handler(Looper.getMainLooper())) {
            @Override protected void onReceiveResult(int cod, Bundle b) {
                if (nr != rulareNr) return;
                if (cod == Rulare.PID) { pidRulare = b.getInt("pid"); return; }
                if (cod == Rulare.PORNESC) {                    // de aici numar cele 20 de secunde
                    stat("rulez…");
                    new Handler(Looper.getMainLooper()).postDelayed(new Runnable() { public void run() {
                        if (ruleaza && nr == rulareNr) opreste("L-am oprit după 20 de secunde. Probabil are o buclă care nu se mai termină (un WHILE a cărui condiție rămâne mereu adevărată?).");
                    }}, 20000);
                    return;
                }
                gataRulare();
                eula(b.getString(Rulare.R));
                if (!b.getString(Rulare.R).startsWith("oberonc n-a primit") && !b.getString(Rulare.R).startsWith("Ca să rulez")) lectie(t);
            }
        });
        try { startService(i); }
        catch (Throwable x) { gataRulare(); eula("Nu pot porni atelierul de rulat: " + greseala(x)); return; }
        stat("compilez…");
    }

    void gataRulare() {
        ruleaza = false;
        rulez.setText("Rulează");
        stat();
    }

    /** opresc procesul de rulare si arat ce apucase programul sa scrie */
    void opreste(String de_ce) {
        rulareNr++;
        int pid = pidRulare;
        if (pid != 0 && pid != android.os.Process.myPid()) android.os.Process.killProcess(pid);
        pidRulare = 0;
        gataRulare();
        String s = Rulator.citeste(Rulare.iesire(this));
        while (s.endsWith("\n")) s = s.substring(0, s.length() - 1);
        if (s.length() > 3000) s = "…" + s.substring(s.length() - 3000);
        eula(de_ce + (s.isEmpty() ? "" : "\nCe apucase să scrie:\n" + C0 + s + C1));
    }

    /** dupa o rulare reusita, vad si daca exercitiul lectiei e facut (doar randul cu ✓) */
    void lectie(final String t) {
        fir(new Runnable() { public void run() {
            try {
                String r;
                synchronized (Oberon.LOCK) { r = Oberon.verifica(t); }
                for (String l : r.split("\n")) if (l.contains("✓ Exercițiul")) { eula(l.trim()); break; }
            } catch (Throwable x) { /* nimic */ }
        }});
    }

    void feed() {
        final String t = input.getText().toString();
        if (t.trim().isEmpty() || busy) return;
        input.setText("");
        boolean cod;
        try { synchronized (Oberon.LOCK) { cod = Oberon.pareCod(t); } } catch (Throwable x) { cod = false; }
        say(ACCENT, "Tu (de mâncare): ", cod ? C0 + t + C1 : t);
        busy = true;
        fir(new Runnable() { public void run() {
            try {
                int k = eat(t, "conversație");
                String r;
                synchronized (Oberon.LOCK) { r = Oberon.mancat(k); }
                eula(r);
            } catch (Throwable x) { eula("Am pățit ceva: " + greseala(x)); }
            busy = false;
            stat();
        }});
    }

    int eat(String text, String src) throws Exception {
        long now = System.currentTimeMillis();
        int k;
        synchronized (Oberon.LOCK) {                      // fisierul si memoria se schimba impreuna
            OutputStream o = new FileOutputStream(memFile(), true);
            o.write(("\n" + REC + now + "\t" + src.replace('\n', ' ').replace('\t', ' ') + "\n").getBytes("UTF-8"));
            o.write(text.getBytes("UTF-8"));
            o.close();
            k = Oberon.mananca(text, src);
        }
        dirty = true;
        return k;
    }

    void pickImport() {
        if (busy) return;
        Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType("*/*");
        try { startActivityForResult(i, IMPORT); }
        catch (Exception e) { say(DIM, null, "Telefonul nu mă lasă să aleg un fișier."); }
    }

    @Override protected void onActivityResult(int req, int res, Intent data) {
        if (req != IMPORT) return;
        if (res != RESULT_OK || data == null || data.getData() == null) { say(DIM, null, "N-ai ales niciun fișier."); return; }
        final Uri u = data.getData();
        busy = true;
        say(DIM, null, "Import…");
        fir(new Runnable() { public void run() {
            try {
                byte[] raw = readAll(getContentResolver().openInputStream(u));
                String name = u.getLastPathSegment() != null ? u.getLastPathSegment() : "fișier";
                int sl = name.lastIndexOf('/');
                if (sl >= 0) name = name.substring(sl + 1);
                int k = eat(text(raw, 0, raw.length), "importat: " + name);
                saveSnap();
                String r;
                synchronized (Oberon.LOCK) { r = Oberon.mancat(k); }
                eula(r);
            } catch (Throwable t) {
                eula("Importul n-a mers: " + greseala(t));
            }
            busy = false;
            stat();
        }});
    }
}
