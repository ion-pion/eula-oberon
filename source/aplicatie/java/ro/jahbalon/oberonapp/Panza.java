package ro.jahbalon.oberonapp;

import android.content.Context;
import android.graphics.Canvas;

/** starea comuna dintre lansator si modulele Ecran/Senzor (care stau fara pachet, cum le cere oberonc) */
public final class Panza {
    private Panza() {}
    public static Canvas c;
    public static int w, h, atinsX, atinsY;
    public static float d = 1;
    public static boolean apasat;
    public static Context ctx;
    public static Runnable pauza, reia;     // le pune Senzor cand porneste
    public static volatile boolean activ = true;   // aplicatia e in fata (Sunet tace cand nu e)
    public static android.view.View vedere;        // v24: panza, ca sa poata primi tastatura
    public static final StringBuilder taste = new StringBuilder();   // v24: literele scrise, le ia Ecran.Tasta
    public static final Object lacat = new Object();   // v27: Deseneaza, Atinge si Retea nu ruleaza niciodata deodata
    public static java.lang.reflect.Method retea;      // v27: Modul.Retea, daca exista (o cheama socket-ul lui Ecran)
    public static java.lang.reflect.Method fundal;     // v33: Modul.Fundal, daca exista: chemata cat aplicatia nu e pe ecran
    public static volatile String eroareFundal;        // v33: Fundal s-a oprit cu o eroare (o arata Deseneaza)
}
