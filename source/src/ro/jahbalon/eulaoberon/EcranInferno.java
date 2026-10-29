package ro.jahbalon.eulaoberon;

import android.app.Activity;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.os.Bundle;
import android.text.InputType;
import android.util.TypedValue;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.io.*;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.LinkedBlockingQueue;

/**
 * Ecranul lui Inferno: porneste emulatorul (libinfernoemu.so) cu wm/wm si, la cerere, Charon.
 * Emulatorul deseneaza intr-un fisier mapat (antet "IFB1", apoi pixeli RGBA), iar noi il aratam marit de
 * SCARA ori; atingerile si tastele merg inapoi pe un FIFO, cate un rand: "m x y butoane", "k cod".
 */
public class EcranInferno extends Activity {
    static final int VIOLET = 0xFF16042A, VIOLET2 = 0xFF240A42, AUR = 0xFFC9A85E;

    int scara = 2;
    Panza panza;
    TextView mesaj;
    LinearLayout bara;
    Process proces;
    File fb, fifo, jurnal;
    volatile boolean gata;
    final LinkedBlockingQueue<String> coada = new LinkedBlockingQueue<String>();
    String[] program;          // ce porneste wm: {"charon", url} sau nimic (biroul)

    int dp(float v) { return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, getResources().getDisplayMetrics()); }

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        getWindow().setStatusBarColor(VIOLET);
        getWindow().setNavigationBarColor(VIOLET);
        String p = getIntent().getStringExtra("program");
        program = p == null || p.trim().isEmpty() ? new String[0] : p.trim().split("\\s+");
        scara = getSharedPreferences("eulaoberon", 0).getInt("inferno-scara", 2);

        FrameLayout rad = new FrameLayout(this);
        rad.setBackgroundColor(Color.BLACK);
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        panza = new Panza(this);
        col.addView(panza, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        bara = new LinearLayout(this);
        bara.setBackgroundColor(VIOLET2);
        buton("⌨", new View.OnClickListener() { public void onClick(View v) { tastatura(); } });
        buton("▲", new View.OnClickListener() { public void onClick(View v) { rotita(8, 3); } });
        buton("▼", new View.OnClickListener() { public void onClick(View v) { rotita(16, 3); } });
        buton("ESC", new View.OnClickListener() { public void onClick(View v) { tasta(27); } });
        buton("⏎", new View.OnClickListener() { public void onClick(View v) { tasta(10); } });
        buton("×" + (scara == 2 ? "3" : "2"), new View.OnClickListener() { public void onClick(View v) { schimbaScara(); } });
        buton("✕", new View.OnClickListener() { public void onClick(View v) { finish(); } });
        col.addView(bara, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(44)));
        rad.addView(col);
        mesaj = new TextView(this);
        mesaj.setTextColor(AUR);
        mesaj.setTypeface(Typeface.MONOSPACE);
        mesaj.setTextSize(13);
        mesaj.setPadding(dp(14), dp(14), dp(14), dp(14));
        mesaj.setText("Pregătesc Inferno…");
        rad.addView(mesaj, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        setContentView(rad);
        panza.setFocusable(true);
        panza.setFocusableInTouchMode(true);
        panza.requestFocus();
    }

    void buton(String t, View.OnClickListener l) {
        Button b = new Button(this);
        b.setText(t);
        b.setAllCaps(false);
        b.setTextColor(AUR);
        b.setTextSize(15);
        b.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        b.setBackgroundColor(VIOLET2);
        b.setPadding(0, 0, 0, 0);
        b.setOnClickListener(l);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1);
        lp.setMargins(dp(1), dp(3), dp(1), dp(3));
        bara.addView(b, lp);
    }

    void schimbaScara() {
        getSharedPreferences("eulaoberon", 0).edit().putInt("inferno-scara", scara == 2 ? 3 : 2).apply();
        recreate();
    }

    void spune(final String s) {
        runOnUiThread(new Runnable() { public void run() {
            mesaj.setText(s);
            mesaj.setVisibility(s == null ? View.GONE : View.VISIBLE);
        }});
    }

    // ------------------------------------------------------------------ pornirea emulatorului

    /** cand stim marimea panzei: despachetez radacina (o data), apoi pornesc emulatorul */
    void porneste(final int lat, final int inalt) {
        new Thread(new Runnable() { public void run() {
            try {
                File rad = Inferno.pregateste(EcranInferno.this);
                File emu = Inferno.emu(EcranInferno.this);
                if (!emu.exists()) { spune("Lipsește emulatorul: " + emu + "\nAplicația e doar pentru telefoane arm64."); return; }
                File c = getCacheDir();
                fb = new File(c, "inferno.fb");
                fifo = new File(c, "inferno.in");
                jurnal = new File(c, "inferno.jurnal");
                fb.delete();
                fifo.delete();
                android.system.Os.mkfifo(fifo.getAbsolutePath(), 0600);
                int w = (lat / scara) & ~3, h = inalt / scara;
                List<String> a = new ArrayList<String>();
                a.add(emu.getAbsolutePath());
                a.add("-r" + rad.getAbsolutePath());
                a.add("-g" + w + "x" + h);
                a.add("/dis/wm/wm.dis");
                for (String x : program) a.add(x);
                ProcessBuilder pb = new ProcessBuilder(a);
                pb.directory(rad);
                pb.redirectErrorStream(true);
                pb.redirectOutput(jurnal);
                Inferno.mediu(pb.environment(), rad);
                pb.environment().put("EMUFB", fb.getAbsolutePath());
                pb.environment().put("EMUIN", fifo.getAbsolutePath());
                proces = pb.start();
                pornesteScriitor();
                arata(w, h);
            } catch (Throwable t) {
                spune("Inferno n-a pornit: " + t);
            }
        }}, "inferno-porneste").start();
    }

    /** firul care trimite atingerile si tastele pe FIFO */
    void pornesteScriitor() {
        new Thread(new Runnable() { public void run() {
            try {
                OutputStream o = new FileOutputStream(fifo);   // asteapta pana deschide si emulatorul
                while (!gata) {
                    String s = coada.take();
                    if (s.isEmpty()) break;
                    o.write(s.getBytes("UTF-8"));
                    o.flush();
                }
                o.close();
            } catch (Exception e) { /* s-a inchis */ }
        }}, "inferno-intrari").start();
    }

    /** firul care urmareste fisierul ecranului si copiaza pixelii in bitmap cand se schimba contorul */
    void arata(int w, int h) throws Exception {
        long nevoie = 32L + (long) w * h * 4;
        long start = System.currentTimeMillis();
        while (!gata && (!fb.exists() || fb.length() < nevoie)) {
            if (procesMort()) { spune("Inferno s-a oprit:\n" + coada(jurnal)); return; }
            if (System.currentTimeMillis() - start > 60000) { spune("Inferno nu deseneaza nimic:\n" + coada(jurnal)); return; }
            Thread.sleep(50);
        }
        RandomAccessFile raf = new RandomAccessFile(fb, "r");
        MappedByteBuffer m = raf.getChannel().map(FileChannel.MapMode.READ_ONLY, 0, nevoie);
        m.order(ByteOrder.LITTLE_ENDIAN);
        int fw = m.getInt(4), fh = m.getInt(8);
        Bitmap bmp = Bitmap.createBitmap(fw, fh, Bitmap.Config.ARGB_8888);
        panza.bmp = bmp;
        spune(null);
        int ultim = -1;
        while (!gata) {
            int c = m.getInt(12);
            if (c != ultim) {
                ultim = c;
                ByteBuffer pix = m.duplicate();
                pix.position(32);
                pix.limit(32 + fw * fh * 4);
                synchronized (bmp) { bmp.copyPixelsFromBuffer(pix.slice()); }
                panza.postInvalidate();
            }
            if (procesMort()) { spune("Inferno s-a oprit:\n" + coada(jurnal)); break; }
            Thread.sleep(16);
        }
        raf.close();
    }

    boolean procesMort() {
        if (proces == null) return false;
        try { proces.exitValue(); return true; } catch (IllegalThreadStateException e) { return false; }
    }

    static String coada(File f) {
        if (f == null || !f.exists()) return "(fara jurnal)";
        String s = Rulator.citeste(f);
        return s.length() > 1500 ? s.substring(s.length() - 1500) : s;
    }

    @Override protected void onDestroy() {
        gata = true;
        coada.offer("");
        if (proces != null) proces.destroy();
        super.onDestroy();
    }

    // ------------------------------------------------------------------ intrarile

    void trimite(String s) { if (proces != null) coada.offer(s); }

    void mouse(int x, int y, int b) { trimite("m " + x + " " + y + " " + b + "\n"); }

    void tasta(int cod) { if (cod > 0) trimite("k " + cod + "\n"); }

    int ultimX, ultimY;

    void rotita(int buton, int pasi) {
        for (int i = 0; i < pasi; i++) { mouse(ultimX, ultimY, buton); mouse(ultimX, ultimY, 0); }
    }

    void tastatura() {
        panza.requestFocus();
        InputMethodManager im = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
        im.toggleSoftInput(InputMethodManager.SHOW_FORCED, 0);
    }

    /** tastele Android -> codurile Inferno (include/keyboard.h) */
    static int cod(int kc, KeyEvent e) {
        switch (kc) {
            case KeyEvent.KEYCODE_ENTER: case KeyEvent.KEYCODE_NUMPAD_ENTER: return 10;
            case KeyEvent.KEYCODE_DEL: return 8;
            case KeyEvent.KEYCODE_FORWARD_DEL: return 0xE064;
            case KeyEvent.KEYCODE_TAB: return 9;
            case KeyEvent.KEYCODE_ESCAPE: return 27;
            case KeyEvent.KEYCODE_MOVE_HOME: return 0xE010;
            case KeyEvent.KEYCODE_MOVE_END: return 0xE011;
            case KeyEvent.KEYCODE_DPAD_UP: return 0xE012;
            case KeyEvent.KEYCODE_DPAD_DOWN: return 0xE013;
            case KeyEvent.KEYCODE_DPAD_LEFT: return 0xE014;
            case KeyEvent.KEYCODE_DPAD_RIGHT: return 0xE015;
            case KeyEvent.KEYCODE_PAGE_UP: return 0xE016;
            case KeyEvent.KEYCODE_PAGE_DOWN: return 0xE017;
        }
        int u = e.getUnicodeChar();
        if (u > 0 && e.isCtrlPressed() && u >= '@' && u <= '~') u &= 0x1f;
        return u;
    }

    @Override public boolean onKeyDown(int kc, KeyEvent e) {
        if (kc == KeyEvent.KEYCODE_BACK) return super.onKeyDown(kc, e);
        int c = cod(kc, e);
        if (c > 0) { tasta(c); return true; }
        return super.onKeyDown(kc, e);
    }

    /** panza: arata bitmap-ul marit si da mai departe atingerile */
    class Panza extends View {
        volatile Bitmap bmp;
        final Paint p = new Paint();
        final Rect tinta = new Rect();
        boolean pornit;
        float y0;
        int doiDegete;

        Panza(Context c) { super(c); p.setFilterBitmap(false); setBackgroundColor(Color.BLACK); }

        @Override protected void onSizeChanged(int w, int h, int ow, int oh) {
            if (!pornit && w > 0 && h > 0) { pornit = true; porneste(w, h); }
        }

        @Override protected void onDraw(Canvas c) {
            Bitmap b = bmp;
            if (b == null) return;
            tinta.set(0, 0, b.getWidth() * scara, b.getHeight() * scara);
            synchronized (b) { c.drawBitmap(b, null, tinta, p); }
        }

        @Override public boolean onTouchEvent(MotionEvent e) {
            int x = (int) (e.getX() / scara), y = (int) (e.getY() / scara);
            switch (e.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    doiDegete = 0;
                    ultimX = x; ultimY = y;
                    mouse(x, y, 1);
                    break;
                case MotionEvent.ACTION_POINTER_DOWN:
                    // al doilea deget: nu mai e clic, e derulare
                    mouse(ultimX, ultimY, 0);
                    doiDegete = 1;
                    y0 = e.getY(0);
                    break;
                case MotionEvent.ACTION_MOVE:
                    if (doiDegete > 0) {
                        float dy = e.getY(0) - y0;
                        int pas = dp(24);
                        while (Math.abs(dy) >= pas) {
                            rotita(dy > 0 ? 8 : 16, 1);
                            y0 += dy > 0 ? pas : -pas;
                            dy = e.getY(0) - y0;
                        }
                    } else {
                        ultimX = x; ultimY = y;
                        mouse(x, y, 1);
                    }
                    break;
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    if (doiDegete == 0) mouse(x, y, 0);
                    doiDegete = 0;
                    break;
            }
            return true;
        }

        @Override public boolean onCheckIsTextEditor() { return true; }

        @Override public InputConnection onCreateInputConnection(EditorInfo o) {
            o.inputType = InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS;
            o.imeOptions = EditorInfo.IME_FLAG_NO_FULLSCREEN | EditorInfo.IME_FLAG_NO_EXTRACT_UI;
            return new BaseInputConnection(this, false) {
                @Override public boolean commitText(CharSequence t, int poz) {
                    String s = t.toString();
                    for (int i = 0; i < s.length(); ) {
                        int cp = s.codePointAt(i);
                        tasta(cp == '\n' ? 10 : cp);
                        i += Character.charCount(cp);
                    }
                    return true;
                }
                @Override public boolean deleteSurroundingText(int inainte, int dupa) {
                    for (int i = 0; i < inainte; i++) tasta(8);
                    return true;
                }
                @Override public boolean sendKeyEvent(KeyEvent e) {
                    if (e.getAction() == KeyEvent.ACTION_DOWN) {
                        int c = cod(e.getKeyCode(), e);
                        if (c > 0) tasta(c);
                    }
                    return true;
                }
            };
        }
    }
}
