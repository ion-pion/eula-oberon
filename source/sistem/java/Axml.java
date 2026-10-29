import java.io.ByteArrayOutputStream;
import java.io.UnsupportedEncodingException;
import java.util.ArrayList;
import java.util.List;

/**
 * Manifestul binar al Android-ului (formatul AXML), scris de mana: ce face aapt2 cand "compileaza" AndroidManifest.xml.
 * Un fisier AXML = un pachet de bucati (chunk-uri): tabelul de siruri, harta atributelor android:* spre numerele lor
 * de resursa, apoi elementele XML, fiecare cu atributele lui gata tipizate (sir, numar, adevarat/fals, referinta).
 */
final class Axml {
    static final String ANDROID = "http://schemas.android.com/apk/res/android";
    static final int T_REF = 0x01, T_STRING = 0x03, T_INT = 0x10, T_BOOL = 0x12;

    /** atributele android:* folosite si numarul lor de resursa (din android.R.attr) */
    static final String[] ATR = {"label", "name", "exported", "theme", "versionCode", "versionName", "minSdkVersion",
        "targetSdkVersion", "value", "screenOrientation", "configChanges", "icon", "drawable", "windowSoftInputMode", "largeHeap",
        // v29: pentru apk ... eula (Eula Oberon in aceeasi aplicatie)
        "process", "taskAffinity", "authorities", "grantUriPermissions", "launchMode", "extractNativeLibs",
        "requestLegacyExternalStorage"};
    static final int[] ATR_ID = {0x01010001, 0x01010003, 0x01010010, 0x01010000, 0x0101021b, 0x0101021c, 0x0101020c,
        0x01010270, 0x01010024, 0x0101001e, 0x0101001f, 0x01010002, 0x01010199, 0x0101022b, 0x0101035a,
        0x01010011, 0x01010012, 0x01010018, 0x0101001b, 0x0101001d, 0x010104ea, 0x01010603};

    final List<String> siruri = new ArrayList<String>();
    final ByteArrayOutputStream corp = new ByteArrayOutputStream();

    Axml() {
        for (String a : ATR) siruri.add(a);     // primele siruri = atributele din harta de resurse, in aceeasi ordine
    }

    int sir(String s) {
        int i = siruri.indexOf(s);
        if (i >= 0) return i;
        siruri.add(s);
        return siruri.size() - 1;
    }

    static final class Atr {
        String ns, nume, sirVal;
        int tip, data;
    }

    static Atr a(String nume, String sir) { Atr x = new Atr(); x.ns = ANDROID; x.nume = nume; x.tip = T_STRING; x.sirVal = sir; return x; }
    static Atr a(String nume, int tip, int data) { Atr x = new Atr(); x.ns = ANDROID; x.nume = nume; x.tip = tip; x.data = data; return x; }
    static Atr simplu(String nume, String sir) { Atr x = a(nume, sir); x.ns = null; return x; }

    private void u16(ByteArrayOutputStream o, int v) { o.write(v & 255); o.write(v >> 8 & 255); }
    private void u32(ByteArrayOutputStream o, int v) { u16(o, v); u16(o, v >>> 16); }

    void incepeNs() {
        u16(corp, 0x0100); u16(corp, 16); u32(corp, 24);
        u32(corp, 1); u32(corp, -1);
        u32(corp, sir("android")); u32(corp, sir(ANDROID));
    }

    void terminaNs() {
        u16(corp, 0x0101); u16(corp, 16); u32(corp, 24);
        u32(corp, 1); u32(corp, -1);
        u32(corp, sir("android")); u32(corp, sir(ANDROID));
    }

    void incepe(String tag, Atr... at) {
        // atributele trebuie sortate dupa numarul de resursa (cum le pune aapt2); cele fara ns la sfarsit
        Atr[] s = at.clone();
        java.util.Arrays.sort(s, new java.util.Comparator<Atr>() {
            public int compare(Atr x, Atr y) { return Long.compare(cheie(x), cheie(y)); }
        });
        u16(corp, 0x0102); u16(corp, 16); u32(corp, 36 + 20 * s.length);
        u32(corp, 1); u32(corp, -1);
        u32(corp, -1); u32(corp, sir(tag));
        u16(corp, 20); u16(corp, 20); u16(corp, s.length);
        u16(corp, 0); u16(corp, 0); u16(corp, 0);     // index id, class, style
        for (Atr x : s) {
            u32(corp, x.ns == null ? -1 : sir(x.ns));
            u32(corp, sir(x.nume));
            u32(corp, x.tip == T_STRING ? sir(x.sirVal) : -1);
            u16(corp, 8); corp.write(0); corp.write(x.tip);
            u32(corp, x.tip == T_STRING ? sir(x.sirVal) : x.data);
        }
    }

    static long cheie(Atr x) {
        if (x.ns == null) return 0x7fffffffL + 1;
        for (int i = 0; i < ATR.length; i++) if (ATR[i].equals(x.nume)) return ATR_ID[i] & 0xffffffffL;
        throw new IllegalArgumentException("atribut necunoscut: " + x.nume);
    }

    void termina(String tag) {
        u16(corp, 0x0103); u16(corp, 16); u32(corp, 24);
        u32(corp, 1); u32(corp, -1);
        u32(corp, -1); u32(corp, sir(tag));
    }

    byte[] gata() throws UnsupportedEncodingException {
        // tabelul de siruri, UTF-16 (fara stiluri)
        ByteArrayOutputStream date = new ByteArrayOutputStream();
        int[] poz = new int[siruri.size()];
        for (int i = 0; i < siruri.size(); i++) {
            poz[i] = date.size();
            String s = siruri.get(i);
            u16(date, s.length());
            byte[] b = s.getBytes("UTF-16LE");
            date.write(b, 0, b.length);
            u16(date, 0);
        }
        while (date.size() % 4 != 0) date.write(0);
        ByteArrayOutputStream sp = new ByteArrayOutputStream();
        int antet = 28, start = antet + 4 * siruri.size();
        u16(sp, 0x0001); u16(sp, antet); u32(sp, start + date.size());
        u32(sp, siruri.size()); u32(sp, 0); u32(sp, 0); u32(sp, start); u32(sp, 0);
        for (int p : poz) u32(sp, p);
        byte[] d = date.toByteArray();
        sp.write(d, 0, d.length);
        // harta de resurse: primele ATR.length siruri
        ByteArrayOutputStream rm = new ByteArrayOutputStream();
        u16(rm, 0x0180); u16(rm, 8); u32(rm, 8 + 4 * ATR_ID.length);
        for (int id : ATR_ID) u32(rm, id);
        ByteArrayOutputStream tot = new ByteArrayOutputStream();
        int n = 8 + sp.size() + rm.size() + corp.size();
        u16(tot, 0x0003); u16(tot, 8); u32(tot, n);
        tot.write(sp.toByteArray(), 0, sp.size());
        tot.write(rm.toByteArray(), 0, rm.size());
        tot.write(corp.toByteArray(), 0, corp.size());
        return tot.toByteArray();
    }

    static byte[] manifest(String pachet, String eticheta, String modul, int versiune, int iconita) throws UnsupportedEncodingException {
        return manifest(pachet, eticheta, modul, versiune, iconita, false);
    }

    /** manifestul unei aplicatii Oberon: o activitate (lansatorul) care porneste modulul. vorbeste = aplicatie de
     *  conversatie (v21): tema cu bara de sus, tastatura micsoreaza fereastra, memorie mare (largeHeap). */
    static byte[] manifest(String pachet, String eticheta, String modul, int versiune, int iconita, boolean vorbeste) throws UnsupportedEncodingException {
        Axml x = new Axml();
        x.incepeNs();
        x.incepe("manifest", a("versionCode", T_INT, versiune), a("versionName", "1." + versiune), simplu("package", pachet));
        x.incepe("uses-sdk", a("minSdkVersion", T_INT, 21), a("targetSdkVersion", T_INT, 28));
        x.termina("uses-sdk");
        if (vorbeste) {
            for (String perm : new String[] {"INTERNET", "READ_EXTERNAL_STORAGE", "WRITE_EXTERNAL_STORAGE"}) {
                x.incepe("uses-permission", a("name", "android.permission." + perm));
                x.termina("uses-permission");
            }
            x.incepe("application", a("label", eticheta), a("theme", T_REF, 0x0103022e), a("icon", T_REF, iconita),   // Theme.Material.NoActionBar
                a("largeHeap", T_BOOL, -1));
            x.incepe("activity", a("name", "ro.jahbalon.oberonapp.Lansator"), a("exported", T_BOOL, -1),
                a("label", eticheta), a("screenOrientation", T_INT, 1), a("configChanges", T_INT, 0x4a0),
                a("windowSoftInputMode", T_INT, 0x10));   // adjustResize
        } else {
        // v25: si aplicatiile pe panza pot citi fisierele telefonului (Ecran.Descarcari cere voie)
        // v28: si FOREGROUND_SERVICE: cat asculta socket-ul, serviciul Treaz tine aplicatia treaza in spate
        // v27: si INTERNET, pentru socket-ul lui Ecran (Asculta pe 127.0.0.1; fara voie Android nu-l deschide)
        for (String perm : new String[] {"INTERNET", "FOREGROUND_SERVICE", "WAKE_LOCK", "READ_EXTERNAL_STORAGE", "WRITE_EXTERNAL_STORAGE"}) {
            x.incepe("uses-permission", a("name", "android.permission." + perm));
            x.termina("uses-permission");
        }
        x.incepe("application", a("label", eticheta), a("theme", T_REF, 0x01030007), a("icon", T_REF, iconita));   // Theme.NoTitleBar.Fullscreen
        // in picioare (portret): senzorii (busola, gravitatia) au axele telefonului, desenul pe ale ecranului
        x.incepe("activity", a("name", "ro.jahbalon.oberonapp.Lansator"), a("exported", T_BOOL, -1),
            a("label", eticheta), a("screenOrientation", T_INT, 1), a("configChanges", T_INT, 0x4a0));   // orientation|keyboardHidden|screenSize
        }
        x.incepe("intent-filter");
        x.incepe("action", a("name", "android.intent.action.MAIN"));
        x.termina("action");
        x.incepe("category", a("name", "android.intent.category.LAUNCHER"));
        x.termina("category");
        x.termina("intent-filter");
        x.incepe("meta-data", a("name", "oberon.modul"), a("value", modul));
        x.termina("meta-data");
        x.termina("activity");
        if (!vorbeste) {   // v28: serviciul care tine aplicatia treaza cat asculta Ecran.Asculta
            x.incepe("service", a("name", "ro.jahbalon.oberonapp.Treaz"), a("exported", T_BOOL, 0));
            x.termina("service");
        }
        x.termina("application");
        x.termina("manifest");
        x.terminaNs();
        return x.gata();
    }

    /** v29: aplicatia cu Eula Oberon inauntru (apk X.Mod "Nume" eula): lansatorul modulului (iconita) + activitatile,
     *  furnizorul si serviciile Eulei, cu numele (autoritate, afinitate) mutate in pachetul nou, ca sa stea langa
     *  Eula Oberon instalata fara sa se incurce. */
    static byte[] manifestEula(String pachet, String eticheta, String modul, int versiune, int iconita) throws UnsupportedEncodingException {
        final int MATERIAL = 0x0103022e, FULLSCREEN = 0x01030007, CFG = 0x1ff0, CFG_APP = 0x4a0, RESIZE = 0x10, SINGLE_TASK = 2;
        final String E = "ro.jahbalon.eulaoberon.";
        Axml x = new Axml();
        x.incepeNs();
        x.incepe("manifest", a("versionCode", T_INT, versiune), a("versionName", "1." + versiune), simplu("package", pachet));
        x.incepe("uses-sdk", a("minSdkVersion", T_INT, 21), a("targetSdkVersion", T_INT, 28));
        x.termina("uses-sdk");
        for (String perm : new String[] {"INTERNET", "FOREGROUND_SERVICE", "WAKE_LOCK", "READ_EXTERNAL_STORAGE", "WRITE_EXTERNAL_STORAGE", "REQUEST_INSTALL_PACKAGES"}) {
            x.incepe("uses-permission", a("name", "android.permission." + perm));
            x.termina("uses-permission");
        }
        x.incepe("application", a("label", eticheta), a("theme", T_REF, FULLSCREEN), a("icon", T_REF, iconita),
            a("largeHeap", T_BOOL, -1), a("extractNativeLibs", T_BOOL, -1), a("requestLegacyExternalStorage", T_BOOL, -1));
        // 1. modulul tau: singura iconita
        x.incepe("activity", a("name", "ro.jahbalon.oberonapp.Lansator"), a("exported", T_BOOL, -1),
            a("label", eticheta), a("screenOrientation", T_INT, 1), a("configChanges", T_INT, CFG_APP));
        x.incepe("intent-filter");
        x.incepe("action", a("name", "android.intent.action.MAIN"));
        x.termina("action");
        x.incepe("category", a("name", "android.intent.category.LAUNCHER"));
        x.termina("category");
        x.termina("intent-filter");
        x.incepe("meta-data", a("name", "oberon.modul"), a("value", modul));
        x.termina("meta-data");
        x.termina("activity");
        // 2. Eula Oberon
        x.incepe("activity", a("name", E + "EulaOberon"), a("exported", T_BOOL, 0), a("label", "Eula Oberon"),
            a("launchMode", T_INT, SINGLE_TASK), a("windowSoftInputMode", T_INT, RESIZE), a("theme", T_REF, MATERIAL));
        x.termina("activity");
        x.incepe("activity", a("name", E + "Terminal"), a("exported", T_BOOL, 0), a("label", "Eula Terminal"),
            a("launchMode", T_INT, SINGLE_TASK), a("taskAffinity", pachet + ".terminal"), a("configChanges", T_INT, CFG),
            a("windowSoftInputMode", T_INT, RESIZE), a("theme", T_REF, MATERIAL));
        x.termina("activity");
        x.incepe("activity", a("name", E + "EcranInferno"), a("exported", T_BOOL, 0), a("label", "Inferno"),
            a("taskAffinity", pachet + ".terminal"), a("screenOrientation", T_INT, 1), a("configChanges", T_INT, CFG),
            a("windowSoftInputMode", T_INT, RESIZE), a("theme", T_REF, MATERIAL));
        x.termina("activity");
        x.incepe("provider", a("name", E + "Furnizor"), a("authorities", pachet + ".fisiere"), a("exported", T_BOOL, 0),
            a("grantUriPermissions", T_BOOL, -1));
        x.termina("provider");
        x.incepe("service", a("name", E + "Rulare"), a("process", ":rulare"), a("exported", T_BOOL, 0));
        x.termina("service");
        x.incepe("service", a("name", "ro.jahbalon.oberonapp.Treaz"), a("exported", T_BOOL, 0));
        x.termina("service");
        x.termina("application");
        x.termina("manifest");
        x.terminaNs();
        return x.gata();
    }

    /** iconita adaptiva (res/mipmap-anydpi-v26): fondul si fata, doua desene din drawable */
    static byte[] iconitaAdaptiva(int fond, int fata) throws UnsupportedEncodingException {
        Axml x = new Axml();
        x.incepeNs();
        x.incepe("adaptive-icon");
        x.incepe("background", a("drawable", T_REF, fond));
        x.termina("background");
        x.incepe("foreground", a("drawable", T_REF, fata));
        x.termina("foreground");
        x.termina("adaptive-icon");
        x.terminaNs();
        return x.gata();
    }

    /** manifestul unei aplicatii facute dintr-o pagina HTML: pielea WebView (ro.jahbalon.webapp.Pagina) */
    static byte[] pagina(String pachet, String eticheta, int versiune, int iconita) throws UnsupportedEncodingException {
        Axml x = new Axml();
        x.incepeNs();
        x.incepe("manifest", a("versionCode", T_INT, versiune), a("versionName", "1." + versiune), simplu("package", pachet));
        x.incepe("uses-sdk", a("minSdkVersion", T_INT, 21), a("targetSdkVersion", T_INT, 28));
        x.termina("uses-sdk");
        x.incepe("uses-permission", a("name", "android.permission.INTERNET"));
        x.termina("uses-permission");
        x.incepe("uses-permission", a("name", "android.permission.VIBRATE"));
        x.termina("uses-permission");
        x.incepe("application", a("label", eticheta), a("theme", T_REF, 0x01030007), a("icon", T_REF, iconita));   // Theme.NoTitleBar.Fullscreen
        x.incepe("activity", a("name", "ro.jahbalon.webapp.Pagina"), a("exported", T_BOOL, -1),
            a("label", eticheta), a("configChanges", T_INT, 0x4a0));   // orientation|keyboardHidden|screenSize
        x.incepe("intent-filter");
        x.incepe("action", a("name", "android.intent.action.MAIN"));
        x.termina("action");
        x.incepe("category", a("name", "android.intent.category.LAUNCHER"));
        x.termina("category");
        x.termina("intent-filter");
        x.termina("activity");
        x.termina("application");
        x.termina("manifest");
        x.terminaNs();
        return x.gata();
    }
}
