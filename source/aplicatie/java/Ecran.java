import android.graphics.Canvas;
import ro.jahbalon.oberonapp.Panza;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;

/** Ecran (vezi sistem/def/Ecran.Mod): desenul aplicatiilor Oberon. Coordonatele sunt in pixeli, (0,0) sus-stanga. */
public final class Ecran {
    private Ecran() {}
    static final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
    static { p.setTypeface(Typeface.DEFAULT_BOLD); p.setTextAlign(Paint.Align.CENTER); }


    public static int Latime() { return Panza.w; }
    public static int Inaltime() { return Panza.h; }
    public static int Densitate() { return Math.round(Panza.d * 100); }
    public static int RGB(int r, int g, int b) { return 0xFF000000 | (r & 255) << 16 | (g & 255) << 8 | (b & 255); }
    public static void Fond(int col) { Canvas c = Panza.c; if (c != null) c.drawColor(col); }
    public static void Culoare(int col) { p.setColor(col); }
    public static void Grosime(int g) { p.setStrokeWidth(g); }
    public static void Linie(int x0, int y0, int x1, int y1) { Canvas c = Panza.c; if (c != null) { p.setStyle(Paint.Style.STROKE); c.drawLine(x0, y0, x1, y1, p); } }
    public static void Cerc(int x, int y, int r) { Canvas c = Panza.c; if (c != null) { p.setStyle(Paint.Style.STROKE); c.drawCircle(x, y, r, p); } }
    public static void Disc(int x, int y, int r) { Canvas c = Panza.c; if (c != null) { p.setStyle(Paint.Style.FILL); c.drawCircle(x, y, r, p); } }
    public static void Dreptunghi(int x, int y, int lw, int lh) { Canvas c = Panza.c; if (c != null) { p.setStyle(Paint.Style.FILL); c.drawRect(x, y, x + lw, y + lh, p); } }
    public static void Triunghi(int x0, int y0, int x1, int y1, int x2, int y2) {
        Canvas c = Panza.c;
        if (c == null) return;
        android.graphics.Path t = new android.graphics.Path();
        t.moveTo(x0, y0); t.lineTo(x1, y1); t.lineTo(x2, y2); t.close();
        p.setStyle(Paint.Style.FILL);
        c.drawPath(t, p);
    }
    /** text centrat pe x; y = linia de baza; marime in pixeli */
    public static void Text(int x, int y, int marime, char[] s) {
        Canvas c = Panza.c;
        if (c == null) return;
        int k = 0;
        while (k < s.length && s[k] != 0) k++;
        p.setStyle(Paint.Style.FILL);
        p.setTextSize(marime);
        c.drawText(new String(s, 0, k), x, y, p);
    }
    public static int AtinsX() { return Panza.atinsX; }
    public static int AtinsY() { return Panza.atinsY; }
    public static boolean Apasat() { return Panza.apasat; }

    /** v24: arata (TRUE) sau ascunde tastatura */
    public static void Tastatura(final boolean da) {
        final android.view.View v = Panza.vedere;
        if (v == null) return;
        v.post(new Runnable() { public void run() {
            android.view.inputmethod.InputMethodManager imm =
                (android.view.inputmethod.InputMethodManager) v.getContext().getSystemService(android.content.Context.INPUT_METHOD_SERVICE);
            if (imm == null) return;
            if (da) { v.requestFocus(); imm.showSoftInput(v, android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT); }
            else imm.hideSoftInputFromWindow(v.getWindowToken(), 0);
        }});
    }

    /** v24: urmatoarea litera scrisa (0 = nimic; 13 = Enter; 8 = sterge) */
    public static int Tasta() {
        StringBuilder t = Panza.taste;
        if (t.length() == 0) return 0;
        char c = t.charAt(0); t.deleteCharAt(0);
        return c;
    }

    /** v24: porneste alta aplicatie. tinta = "pachet" sau "Eticheta", mai multe despartite cu | (prima care exista) */
    public static boolean Lanseaza(char[] tinta) {
        android.content.Context c = Panza.ctx;
        if (c == null) return false;
        int k = 0; while (k < tinta.length && tinta[k] != 0) k++;
        android.content.pm.PackageManager pm = c.getPackageManager();
        for (String x : new String(tinta, 0, k).split("\\|")) {
            x = x.trim();
            if (x.isEmpty()) continue;
            android.content.Intent i = null;
            // v29: daca Eula Oberon e chiar in aplicatia asta (apk X.Mod "Nume" eula), o deschid pe ea, nu pe cea instalata
            if ((x.equals("ro.jahbalon.eulaoberon") || x.equalsIgnoreCase("Eula Oberon")) && !c.getPackageName().equals("ro.jahbalon.eulaoberon")) {
                try {
                    Class<?> eo = Class.forName("ro.jahbalon.eulaoberon.EulaOberon", false, c.getClassLoader());
                    i = new android.content.Intent(c, eo);
                } catch (Throwable t) { i = null; }
            }
            if (i != null) { i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK); try { c.startActivity(i); return true; } catch (Exception e) { i = null; } }
            if (x.matches("[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)+")) i = pm.getLaunchIntentForPackage(x);
            else {
                android.content.Intent q = new android.content.Intent(android.content.Intent.ACTION_MAIN).addCategory(android.content.Intent.CATEGORY_LAUNCHER);
                String mic = x.toLowerCase();
                for (android.content.pm.ResolveInfo r : pm.queryIntentActivities(q, 0)) {
                    String et = String.valueOf(r.loadLabel(pm)).toLowerCase();
                    if (et.equals(mic) || et.contains(mic)) {
                        i = new android.content.Intent(android.content.Intent.ACTION_MAIN).addCategory(android.content.Intent.CATEGORY_LAUNCHER)
                            .setClassName(r.activityInfo.packageName, r.activityInfo.name);
                        if (et.equals(mic)) break;
                    }
                }
            }
            if (i != null) {
                i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK);
                try { c.startActivity(i); return true; } catch (Exception e) { /* urmatoarea */ }
            }
        }
        return false;
    }

    // ------------------------------------------------------------------ v25: fisierele telefonului

    static final int ALEGE = 4243;
    static final java.util.concurrent.ConcurrentLinkedQueue<String[]> alese = new java.util.concurrent.ConcurrentLinkedQueue<String[]>();
    static int nrAles = 0;
    static java.io.File[] lista = new java.io.File[0];

    static void pune(String x, char[] d) {
        int k = Math.min(x.length(), d.length - 1);
        x.getChars(0, k, d, 0);
        d[k] = 0;
    }

    /** alegatorul telefonului (ACTION_OPEN_DOCUMENT, mai multe deodata); rezultatul vine prin Lansator.onActivityResult */
    public static void AlegeFisier() {
        final android.content.Context c = Panza.ctx;
        if (!(c instanceof android.app.Activity)) return;
        final android.app.Activity a = (android.app.Activity) c;
        a.runOnUiThread(new Runnable() { public void run() {
            android.content.Intent i = new android.content.Intent(android.content.Intent.ACTION_OPEN_DOCUMENT);
            i.addCategory(android.content.Intent.CATEGORY_OPENABLE);
            i.setType("*/*");
            i.putExtra(android.content.Intent.EXTRA_ALLOW_MULTIPLE, true);
            try { a.startActivityForResult(i, ALEGE); } catch (Throwable t) { /* telefonul n-are alegator */ }
        }});
    }

    /** chemat de Lansator: copiaza fisierele alese in dosarul aplicatiei (pe alt fir), apoi le da lui Ales */
    public static void rezultat(int req, int res, android.content.Intent data) {
        if (req != ALEGE || res != android.app.Activity.RESULT_OK || data == null) return;
        final android.content.Context c = Panza.ctx;
        final java.util.List<android.net.Uri> u = new java.util.ArrayList<android.net.Uri>();
        if (data.getClipData() != null) for (int i = 0; i < data.getClipData().getItemCount(); i++) u.add(data.getClipData().getItemAt(i).getUri());
        else if (data.getData() != null) u.add(data.getData());
        new Thread(new Runnable() { public void run() {
            java.io.File d = new java.io.File(c.getFilesDir(), "alese");
            d.mkdirs();
            for (android.net.Uri x : u) {
                try {
                    java.io.File f = new java.io.File(d, "ales-" + (nrAles++) + ".tmp");
                    java.io.InputStream in = c.getContentResolver().openInputStream(x);
                    java.io.OutputStream o = new java.io.FileOutputStream(f);
                    byte[] b = new byte[1 << 16];
                    int k;
                    while ((k = in.read(b)) > 0) o.write(b, 0, k);
                    o.close(); in.close();
                    alese.add(new String[] {f.getAbsolutePath(), numele(c, x)});
                } catch (Throwable t) { /* fisierul nu se poate citi: il sar */ }
            }
        }}).start();
    }

    static String numele(android.content.Context c, android.net.Uri u) {
        try {
            android.database.Cursor q = c.getContentResolver().query(u, new String[] {android.provider.OpenableColumns.DISPLAY_NAME}, null, null, null);
            if (q != null) {
                String n = q.moveToFirst() && !q.isNull(0) ? q.getString(0) : null;
                q.close();
                if (n != null) return n;
            }
        } catch (Throwable t) { }
        String p = u.getLastPathSegment();
        return p == null ? "fisier" : p.substring(p.lastIndexOf('/') + 1);
    }

    public static boolean Ales(char[] cale, char[] nume) {
        String[] x = alese.poll();
        if (x == null) return false;
        pune(x[0], cale); pune(x[1], nume);
        return true;
    }

    public static boolean Descarcari(char[] d) {
        final android.content.Context c = Panza.ctx;
        if (c == null) return false;
        if (android.os.Build.VERSION.SDK_INT >= 23
                && c.checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            if (c instanceof android.app.Activity) {
                final android.app.Activity a = (android.app.Activity) c;
                a.runOnUiThread(new Runnable() { public void run() {
                    a.requestPermissions(new String[] {android.Manifest.permission.READ_EXTERNAL_STORAGE,
                        android.Manifest.permission.WRITE_EXTERNAL_STORAGE}, 7);
                }});
            }
            return false;
        }
        java.io.File f = android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS);
        if (f == null) return false;
        pune(f.getAbsolutePath(), d);
        return true;
    }

    public static int Intrari(char[] dosar) {
        int k = 0; while (k < dosar.length && dosar[k] != 0) k++;
        java.io.File[] l = new java.io.File(new String(dosar, 0, k)).listFiles();
        if (l == null) { lista = new java.io.File[0]; return -1; }
        java.util.Arrays.sort(l, new java.util.Comparator<java.io.File>() {
            public int compare(java.io.File a, java.io.File b) { return a.getName().compareToIgnoreCase(b.getName()); }
        });
        lista = l;
        return l.length;
    }

    public static int Intrare(int i, char[] nume) {
        if (i < 0 || i >= lista.length) { if (nume.length > 0) nume[0] = 0; return -1; }
        pune(lista[i].getName(), nume);
        return lista[i].isDirectory() ? -1 : (int) Math.min(Integer.MAX_VALUE, lista[i].length());
    }

    /** v26: cand a fost schimbata intrarea i: secunde de la 1 ian 2010 UTC (ca Os.CurrentTime) */
    public static int Schimbat(int i) {
        if (i < 0 || i >= lista.length) return 0;
        return (int) (lista[i].lastModified() / 1000 - 1262304000L);
    }

    // ---------------------------------------------------------------- v27: socket-ul (127.0.0.1; v31: si reteaua, la cerere)
    static java.net.ServerSocket server;
    static volatile java.net.Socket client;
    static final java.io.ByteArrayOutputStream sosit = new java.io.ByteArrayOutputStream();
    static boolean plecat;   // clientul a plecat: Primeste da -1 o data
    static java.util.concurrent.LinkedBlockingQueue<byte[]> deTrimis;
    static int portul = -1;

    /** cheama Modul.Retea (daca exista), niciodata deodata cu Deseneaza / Atinge */
    static void anunta() {
        java.lang.reflect.Method m = Panza.retea;
        if (m == null) return;
        synchronized (Panza.lacat) { try { m.invoke(null); } catch (Throwable t) { } }
    }

    static boolean peRetea;   // v31: serverul asculta pe toata reteaua locala, nu doar pe 127.0.0.1

    /** asculta pe 127.0.0.1:port; un client odata. TRUE = asculta */
    public static synchronized boolean Asculta(int port) { return asculta(port, false); }

    /** v31: asculta pe toate adresele telefonului (reteaua locala, Wi-Fi); un client odata. TRUE = asculta */
    public static synchronized boolean AscultaRetea(int port) { return asculta(port, true); }

    static synchronized boolean asculta(int port, boolean retea) {
        if (server != null && portul == port && peRetea == retea) return true;
        Inchide();
        try {
            final java.net.ServerSocket ss = retea ? new java.net.ServerSocket(port, 4)
                : new java.net.ServerSocket(port, 4, java.net.InetAddress.getByName("127.0.0.1"));
            server = ss; portul = port; peRetea = retea;
            Thread t = new Thread(new Runnable() { public void run() { primeste(ss); } }, "Ecran.Asculta");
            t.setDaemon(true); t.start();
            ro.jahbalon.oberonapp.Treaz.Porneste("ascultă pe " + (retea ? "rețea" : "127.0.0.1") + ":" + port);   // v28: treaz si in spate
            return true;
        } catch (Throwable e) { server = null; portul = -1; return false; }
    }

    /** v31: adresa IPv4 a telefonului in reteaua locala (Wi-Fi), ex. 192.168.1.20; FALSE = nu e in nicio retea */
    public static boolean AdresaMea(char[] s) {
        try {
            for (java.net.NetworkInterface ni : java.util.Collections.list(java.net.NetworkInterface.getNetworkInterfaces())) {
                if (!ni.isUp() || ni.isLoopback()) continue;
                for (java.net.InetAddress a : java.util.Collections.list(ni.getInetAddresses())) {
                    if (a instanceof java.net.Inet4Address && !a.isLoopbackAddress()) { pune(a.getHostAddress(), s); return true; }
                }
            }
        } catch (Throwable e) { }
        if (s.length > 0) s[0] = 0;
        return false;
    }

    // ---------------------------------------------------------------- v31: clientul (Cubicum intreaba alt cub)
    static volatile java.net.Socket spre;            // legatura noastra catre alt server
    static volatile int legatura;                    // 0 nimic, 1 se leaga, 2 legat, -1 n-a mers / s-a rupt
    static final java.io.ByteArrayOutputStream dinspre = new java.io.ByteArrayOutputStream();
    static boolean ruptSpre;                         // legatura s-a rupt: Dinspre da -1 o data
    static java.util.concurrent.LinkedBlockingQueue<byte[]> deTrimisSpre;
    static volatile int generatie;                   // ca un fir vechi sa nu strice o legatura noua

    /** v31: se leaga (in spate, ca ecranul sa nu stea) de gazda:port; TRUE = a pornit; vezi Legatura */
    public static synchronized boolean Leaga(char[] gazda, int port) {
        Dezleaga();
        int k = 0; while (k < gazda.length && gazda[k] != 0) k++;
        final String g = new String(gazda, 0, k).trim(); final int pt = port;
        if (g.length() == 0 || pt <= 0 || pt > 65535) return false;
        final int gen = ++generatie;
        final java.util.concurrent.LinkedBlockingQueue<byte[]> q = new java.util.concurrent.LinkedBlockingQueue<byte[]>();
        synchronized (dinspre) { dinspre.reset(); ruptSpre = false; }
        deTrimisSpre = q; legatura = 1;
        Thread t = new Thread(new Runnable() { public void run() {
            java.net.Socket so = new java.net.Socket();
            try {
                so.connect(new java.net.InetSocketAddress(g, pt), 4000);
                so.setTcpNoDelay(true);
            } catch (Throwable e) {
                try { so.close(); } catch (Throwable x) { }
                if (gen == generatie) legatura = -1;
                return;
            }
            if (gen != generatie) { try { so.close(); } catch (Throwable x) { } return; }
            spre = so; legatura = 2;
            final java.net.Socket s0 = so;
            Thread w = new Thread(new Runnable() { public void run() {   // scrisul, pe firul lui
                try { java.io.OutputStream o = s0.getOutputStream();
                    while (true) { byte[] b = q.take(); if (b.length == 0) break; o.write(b); o.flush(); }
                } catch (Throwable e) { }
            }}, "Ecran.Spre");
            w.setDaemon(true); w.start();
            try {
                java.io.InputStream in = so.getInputStream(); byte[] b = new byte[65536]; int n;
                while ((n = in.read(b)) > 0) { synchronized (dinspre) { dinspre.write(b, 0, n); } }
            } catch (Throwable e) { }
            q.offer(new byte[0]);
            try { so.close(); } catch (Throwable e) { }
            if (gen == generatie) { synchronized (dinspre) { ruptSpre = true; } spre = null; legatura = -1; }
        }}, "Ecran.Leaga");
        t.setDaemon(true); t.start();
        return true;
    }

    /** v31: 0 nimic, 1 se leaga, 2 legat, -1 n-a mers sau s-a rupt */
    public static int Legatura() { return legatura; }

    /** v31: trimite primii n octeti catre serverul de care esti legat */
    public static void Spre(byte[] b, int n) {
        java.util.concurrent.LinkedBlockingQueue<byte[]> q = deTrimisSpre;
        if (q == null || legatura != 2 || n <= 0) return;
        q.offer(java.util.Arrays.copyOf(b, java.lang.Math.min(n, b.length)));
    }

    /** v31: octetii veniti de la server, cat incap in b; 0 = nimic; -1 = legatura s-a rupt (o data) */
    public static int Dinspre(byte[] b) {
        synchronized (dinspre) {
            int n = dinspre.size();
            if (n == 0) { if (ruptSpre) { ruptSpre = false; return -1; } return 0; }
            byte[] t = dinspre.toByteArray(); int k = java.lang.Math.min(n, b.length);
            System.arraycopy(t, 0, b, 0, k);
            dinspre.reset(); if (k < n) dinspre.write(t, k, n - k);
            return k;
        }
    }

    /** v31: inchide legatura catre server */
    public static synchronized void Dezleaga() {
        generatie++;
        java.util.concurrent.LinkedBlockingQueue<byte[]> q = deTrimisSpre;
        if (q != null) q.offer(new byte[0]);
        deTrimisSpre = null;
        java.net.Socket c = spre; spre = null;
        try { if (c != null) c.close(); } catch (Throwable e) { }
        legatura = 0;
        synchronized (dinspre) { dinspre.reset(); ruptSpre = false; }
    }

    static void primeste(java.net.ServerSocket ss) {
        while (!ss.isClosed()) {
            java.net.Socket so;
            try { so = ss.accept(); } catch (Throwable e) { break; }
            try { so.setTcpNoDelay(true); } catch (Throwable e) { }
            final java.util.concurrent.LinkedBlockingQueue<byte[]> q = new java.util.concurrent.LinkedBlockingQueue<byte[]>();
            synchronized (sosit) { sosit.reset(); plecat = false; }
            deTrimis = q; client = so;
            final java.net.Socket s0 = so;
            Thread w = new Thread(new Runnable() { public void run() {   // scrisul, pe firul lui
                try { java.io.OutputStream o = s0.getOutputStream();
                    while (true) { byte[] b = q.take(); if (b.length == 0) break; o.write(b); o.flush(); }
                } catch (Throwable e) { }
            }}, "Ecran.Trimite");
            w.setDaemon(true); w.start();
            anunta();
            try {
                java.io.InputStream in = so.getInputStream(); byte[] b = new byte[65536]; int n;
                while ((n = in.read(b)) > 0) { synchronized (sosit) { sosit.write(b, 0, n); } anunta(); }
            } catch (Throwable e) { }
            q.offer(new byte[0]);
            try { so.close(); } catch (Throwable e) { }
            synchronized (sosit) { plecat = true; }
            client = null;
            anunta();
        }
    }

    /** octetii sositi de la ultima chemare, cat incap in b; 0 = nimic; -1 = clientul a plecat (o data) */
    public static int Primeste(byte[] b) {
        synchronized (sosit) {
            int n = sosit.size();
            if (n == 0) { if (plecat) { plecat = false; return -1; } return 0; }
            byte[] t = sosit.toByteArray(); int k = java.lang.Math.min(n, b.length);
            System.arraycopy(t, 0, b, 0, k);
            sosit.reset(); if (k < n) sosit.write(t, k, n - k);
            return k;
        }
    }

    /** trimite primii n octeti din b clientului legat acum */
    public static void Trimite(byte[] b, int n) {
        java.util.concurrent.LinkedBlockingQueue<byte[]> q = deTrimis;
        if (q == null || client == null || n <= 0) return;
        q.offer(java.util.Arrays.copyOf(b, java.lang.Math.min(n, b.length)));
    }

    /** e un client legat acum */
    public static boolean Legat() { return client != null; }

    /** nu mai asculta; inchide si clientul */
    public static synchronized void Inchide() {
        boolean asculta = server != null;
        try { if (server != null) server.close(); } catch (Throwable e) { }
        server = null; portul = -1; peRetea = false;
        if (asculta) ro.jahbalon.oberonapp.Treaz.Opreste();   // v28
        java.net.Socket c = client;
        try { if (c != null) c.close(); } catch (Throwable e) { }
    }

    // ---------------------------------------------------------------- v32: Aduce - o adresa din internet (https), in spate
    static volatile int adusCod;          // 0 = nimic / inca vine; altfel codul HTTP (-1 = fara retea)
    static volatile boolean aduceAcum;    // o aducere e in curs

    /** v32: porneste aducerea adresei (https, redirectionari) in fisierul cale, ca text UTF-8, pe firul ei;
     *  ecranul nu sta. FALSE = alta aducere e inca in curs. Rezultatul: Adus() */
    public static synchronized boolean Aduce(char[] adresa, char[] cale) {
        if (aduceAcum) return false;
        int k = 0; while (k < adresa.length && adresa[k] != 0) k++;
        final String a = new String(adresa, 0, k).trim();
        k = 0; while (k < cale.length && cale[k] != 0) k++;
        final String c = new String(cale, 0, k);
        if (a.length() == 0 || c.length() == 0) return false;
        aduceAcum = true; adusCod = 0;
        Thread t = new Thread(new Runnable() { public void run() {
            int r;
            try { r = ro.jahbalon.oberonapp.Plasa.aduce(a, c); } catch (Throwable e) { r = -1; }
            if (r == 0) r = -1;
            adusCod = r; aduceAcum = false;
        }}, "Ecran.Aduce");
        t.setDaemon(true); t.start();
        return true;
    }

    /** v32: 0 = inca vine (sau nimic pornit); cand a terminat, o data: codul HTTP (200 = bine), -1 = fara retea */
    public static int Adus() { if (aduceAcum) return 0; int r = adusCod; adusCod = 0; return r; }

    // ---------------------------------------------------------------- v33: treaz, notificari, clipboard
    static String sir(char[] c) { int n = 0; while (n < c.length && c[n] != 0) n++; return new String(c, 0, n); }

    /** tine aplicatia treaza in spate (serviciu cu notificare + procesorul pornit); FALSE = nu mai e nevoie */
    public static void Treaz(boolean da, char[] text) { ro.jahbalon.oberonapp.Treaz.Cere(da, sir(text)); }

    static int nrAnunt = 100;
    /** o notificare pe telefon; atingerea ei deschide aplicatia */
    public static void Anunta(char[] titlu, char[] text) {
        android.content.Context c = Panza.ctx;
        if (c == null) return;
        try {
            c = c.getApplicationContext();
            android.app.NotificationManager nm = (android.app.NotificationManager) c.getSystemService(android.content.Context.NOTIFICATION_SERVICE);
            android.app.Notification.Builder b;
            if (android.os.Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(new android.app.NotificationChannel("anunt", "Anunțuri", android.app.NotificationManager.IMPORTANCE_DEFAULT));
                b = new android.app.Notification.Builder(c, "anunt");
            } else b = new android.app.Notification.Builder(c);
            b.setSmallIcon(android.R.drawable.ic_popup_reminder).setContentTitle(sir(titlu)).setContentText(sir(text)).setAutoCancel(true);
            b.setStyle(new android.app.Notification.BigTextStyle().bigText(sir(text)));
            android.content.Intent d = c.getPackageManager().getLaunchIntentForPackage(c.getPackageName());
            if (d != null) b.setContentIntent(android.app.PendingIntent.getActivity(c, 1, d, android.os.Build.VERSION.SDK_INT >= 23 ? 0x04000000 : 0));
            nm.notify(nrAnunt++, b.build());
        } catch (Throwable t) { }
    }

    /** pune textul in clipboard (din Deseneaza sau Atinge) */
    public static void Copiaza(char[] s) {
        android.content.Context c = Panza.ctx;
        if (c == null) return;
        try {
            android.content.ClipboardManager cm = (android.content.ClipboardManager) c.getSystemService(android.content.Context.CLIPBOARD_SERVICE);
            cm.setPrimaryClip(android.content.ClipData.newPlainText("Oberon", sir(s)));
        } catch (Throwable t) { }
    }

    /** textul din clipboard (din Deseneaza sau Atinge); FALSE = gol sau nu e text */
    public static boolean Lipeste(char[] d) {
        android.content.Context c = Panza.ctx;
        if (d.length > 0) d[0] = 0;
        if (c == null) return false;
        try {
            android.content.ClipboardManager cm = (android.content.ClipboardManager) c.getSystemService(android.content.Context.CLIPBOARD_SERVICE);
            if (!cm.hasPrimaryClip() || cm.getPrimaryClip().getItemCount() == 0) return false;
            CharSequence t = cm.getPrimaryClip().getItemAt(0).coerceToText(c);
            if (t == null || t.length() == 0) return false;
            int n = Math.min(t.length(), d.length - 1);
            for (int i = 0; i < n; i++) d[i] = t.charAt(i);
            d[n] = 0;
            return true;
        } catch (Throwable t) { return false; }
    }
}
