package ro.jahbalon.oberonapp;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

/**
 * Lansatorul aplicatiilor facute cu Eula Oberon: o singura clasa Java, aceeasi in toate aplicatiile. Gaseste modulul
 * Oberon (meta-data "oberon.modul" din manifest), il incarca (corpul lui ruleaza o data) si apoi, la fiecare cadru,
 * cheama Modul.Deseneaza; o atingere cheama Modul.Atinge (daca exista). Desenul trece prin modulul Ecran.
 * Din v21: daca modulul exporta Apasa, aplicatia vorbeste in loc sa deseneze (Vorbire + modulul Conversatie).
 */
public class Lansator extends Activity {
    Method deseneaza, atinge;
    boolean vorbeste;
    String eroare;
    Vedere v;

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        Panza.ctx = this;
        setVolumeControlStream(android.media.AudioManager.STREAM_MUSIC);   // butoanele de volum = volumul muzicii
        try {
            ActivityInfo ai = getPackageManager().getActivityInfo(getComponentName(), PackageManager.GET_META_DATA);
            String m = ai.metaData.getString("oberon.modul");
            Class<?> c = Class.forName(m, true, getClassLoader());
            try { c.getMethod("Apasa"); vorbeste = true; } catch (NoSuchMethodException e) { vorbeste = false; }
            if (vorbeste) { Vorbire.construieste(this, c); return; }
            deseneaza = c.getMethod("Deseneaza");
            try { atinge = c.getMethod("Atinge"); } catch (NoSuchMethodException e) { atinge = null; }
            try { Panza.retea = c.getMethod("Retea"); } catch (NoSuchMethodException e) { Panza.retea = null; }   // v27
            try { Panza.fundal = c.getMethod("Fundal"); } catch (NoSuchMethodException e) { Panza.fundal = null; }   // v33
            if (Panza.fundal != null) pornesteFundal();
        } catch (Throwable t) {
            eroare = text(t);
        }
        v = new Vedere();
        Panza.vedere = v;
        // v24: cand apare tastatura, panza se micsoreaza (Ecran.Inaltime scade), nu fuge in sus
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        setContentView(v);
    }

    /** v33: cat aplicatia nu e pe ecran (in spate, ecran stins), Modul.Fundal e chemata de ~10 ori pe secunda,
     *  pe un fir al ei, niciodata deodata cu Deseneaza / Atinge / Retea. O eroare o opreste (si o arata ecranul). */
    static Thread firFundal;
    static void pornesteFundal() {
        if (firFundal != null) return;
        firFundal = new Thread(new Runnable() { public void run() {
            while (true) {
                try { Thread.sleep(100); } catch (InterruptedException e) { return; }
                java.lang.reflect.Method m = Panza.fundal;
                if (m == null || Panza.eroareFundal != null || Panza.activ) continue;
                synchronized (Panza.lacat) {
                    try { m.invoke(null); } catch (Throwable t) { Panza.eroareFundal = "Fundal: " + text(t); }
                }
            }
        } }, "Modul.Fundal");
        firFundal.setDaemon(true);
        firFundal.start();
    }

    static String text(Throwable t) {
        while (t instanceof InvocationTargetException && ((InvocationTargetException) t).getTargetException() != null)
            t = ((InvocationTargetException) t).getTargetException();
        if (t instanceof ExceptionInInitializerError && t.getCause() != null) t = t.getCause();
        return t.getClass().getSimpleName() + (t.getMessage() != null ? ": " + t.getMessage() : "");
    }

    @Override protected void onResume() { super.onResume(); Panza.activ = true; if (Panza.reia != null) Panza.reia.run(); }
    @Override protected void onPause() {
        Panza.activ = false;
        if (Panza.pauza != null) Panza.pauza.run();
        if (vorbeste) Vorbire.pauza();
        super.onPause();
    }

    @Override protected void onActivityResult(int req, int res, android.content.Intent data) {
        if (vorbeste) Vorbire.rezultat(req, res, data);
        else {   // v25: alegatorul de fisiere al aplicatiilor pe panza (Ecran.AlegeFisier)
            try { Class.forName("Ecran", true, getClassLoader()).getMethod("rezultat", int.class, int.class, android.content.Intent.class).invoke(null, req, res, data); }
            catch (Throwable t) { /* aplicatia nu foloseste Ecran */ }
        }
    }

    class Vedere extends View {
        final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        Vedere() { super(Lansator.this); setFocusable(true); setFocusableInTouchMode(true); }

        // v24: tastatura. TYPE_NULL = tastatura trimite taste, nu text compus; ce vine ca text (diacritice) intra si el.
        @Override public boolean onCheckIsTextEditor() { return true; }
        @Override public android.view.inputmethod.InputConnection onCreateInputConnection(android.view.inputmethod.EditorInfo o) {
            o.inputType = android.text.InputType.TYPE_NULL;
            o.imeOptions = android.view.inputmethod.EditorInfo.IME_FLAG_NO_EXTRACT_UI;
            return new android.view.inputmethod.BaseInputConnection(this, false) {
                @Override public boolean commitText(CharSequence t, int poz) {
                    for (int i = 0; i < t.length(); i++) { char ch = t.charAt(i); Panza.taste.append(ch == '\n' ? '\r' : ch); }
                    return true;
                }
                @Override public boolean deleteSurroundingText(int inainte, int dupa) {
                    for (int i = 0; i < inainte; i++) Panza.taste.append('\b');
                    return true;
                }
            };
        }
        @Override public boolean onKeyDown(int cod, android.view.KeyEvent e) {
            if (cod == android.view.KeyEvent.KEYCODE_ENTER || cod == android.view.KeyEvent.KEYCODE_NUMPAD_ENTER) { Panza.taste.append('\r'); return true; }
            if (cod == android.view.KeyEvent.KEYCODE_DEL) { Panza.taste.append('\b'); return true; }
            int u = e.getUnicodeChar();
            if (u >= 32) { Panza.taste.append((char) u); return true; }
            return super.onKeyDown(cod, e);
        }

        @Override protected void onDraw(Canvas c) {
            if (eroare == null && Panza.eroareFundal != null) eroare = Panza.eroareFundal;   // v33
            if (eroare == null && deseneaza != null) {
                Panza.c = c; Panza.w = getWidth(); Panza.h = getHeight(); Panza.d = getResources().getDisplayMetrics().density;
                synchronized (Panza.lacat) { try { deseneaza.invoke(null); } catch (Throwable t) { eroare = text(t); } }
                Panza.c = null;
            }
            if (eroare != null) {
                c.drawColor(0xFF16042A);
                p.setColor(0xFFC9A85E);
                p.setTextSize(16 * getResources().getDisplayMetrics().density);
                c.drawText("Modulul Oberon s-a oprit:", 30, 120, p);
                c.drawText(eroare, 30, 170, p);
                return;
            }
            postInvalidateOnAnimation();
        }

        @Override public boolean onTouchEvent(MotionEvent e) {
            if (atinge == null) return false;
            Panza.atinsX = (int) e.getX();
            Panza.atinsY = (int) e.getY();
            Panza.apasat = e.getActionMasked() != MotionEvent.ACTION_UP && e.getActionMasked() != MotionEvent.ACTION_CANCEL;
            synchronized (Panza.lacat) { try { atinge.invoke(null); } catch (Throwable t) { eroare = text(t); } }
            return true;
        }
    }
}
