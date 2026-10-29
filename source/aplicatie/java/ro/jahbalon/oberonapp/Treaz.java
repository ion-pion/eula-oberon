package ro.jahbalon.oberonapp;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;

/** v28: cat asculta socket-ul (Ecran.Asculta), aplicatia tine acest serviciu in fata, cu o notificare:
 *  asa Android nu o ingheata cand e in spate. Ecran.Inchide il opreste. */
public class Treaz extends Service {
    public static String text = "ascultă";
    static boolean dinSocket, dinCerere;   // v33: cine vrea serviciul: socket-ul (Ecran.Asculta) si / sau aplicatia (Ecran.Treaz)
    static android.os.PowerManager.WakeLock lacatCpu;   // v33: procesorul ramane pornit si cu ecranul stins

    @Override public void onDestroy() {
        try { if (lacatCpu != null && lacatCpu.isHeld()) lacatCpu.release(); } catch (Throwable t) { }
        lacatCpu = null;
        super.onDestroy();
    }

    @Override public int onStartCommand(Intent i, int f, int id) {
        String eticheta = "Oberon";
        try { eticheta = getPackageManager().getApplicationLabel(getApplicationInfo()).toString(); } catch (Throwable t) { }
        Notification.Builder b;
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
            nm.createNotificationChannel(new NotificationChannel("treaz", "Socket", NotificationManager.IMPORTANCE_LOW));
            b = new Notification.Builder(this, "treaz");
        } else b = new Notification.Builder(this);
        b.setSmallIcon(android.R.drawable.stat_notify_sync).setContentTitle(eticheta).setContentText(text).setOngoing(true);
        Intent deschide = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (deschide != null) b.setContentIntent(android.app.PendingIntent.getActivity(this, 0, deschide,
            Build.VERSION.SDK_INT >= 23 ? 0x04000000 : 0));   // FLAG_IMMUTABLE
        startForeground(7, b.build());
        return START_NOT_STICKY;
    }

    @Override public IBinder onBind(Intent i) { return null; }

    static void porneste(android.content.Context c, String t) {
        text = t;
        try {
            Intent i = new Intent(c, Treaz.class);
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(i); else c.startService(i);
        } catch (Throwable e) { }
    }

    static void opreste(android.content.Context c) {
        try { c.stopService(new Intent(c, Treaz.class)); } catch (Throwable e) { }
    }

    /** pentru Ecran (care sta fara pachet) */
    public static void Porneste(String t) { dinSocket = true; if (Panza.ctx != null) porneste(Panza.ctx.getApplicationContext(), dinCerere ? text : t); }
    public static void Opreste() { dinSocket = false; if (!dinCerere && Panza.ctx != null) opreste(Panza.ctx.getApplicationContext()); }
    /** v33: aplicatia cere sa ramana treaza (Ecran.Treaz) */
    public static void Cere(boolean da, String t) {
        if (Panza.ctx == null) return;
        android.content.Context c = Panza.ctx.getApplicationContext();
        dinCerere = da;
        try {   // procesorul ramane pornit doar cat cere aplicatia (nu si pentru socket: bateria)
            if (lacatCpu == null) {
                android.os.PowerManager pm = (android.os.PowerManager) c.getSystemService(POWER_SERVICE);
                lacatCpu = pm.newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, c.getPackageName() + ":treaz");
                lacatCpu.setReferenceCounted(false);
            }
            if (da && !lacatCpu.isHeld()) lacatCpu.acquire();
            if (!da && lacatCpu.isHeld()) lacatCpu.release();
        } catch (Throwable e) { }
        if (da) porneste(c, t);
        else if (!dinSocket) opreste(c);
    }
}
