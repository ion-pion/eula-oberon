import java.io.*;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

import ro.jahbalon.eulaoberon.Dx;
import ro.jahbalon.eulaoberon.Rulator;

/**
 * Pachet (vezi def/Pachet.Mod): un APK dintr-un modul Oberon, facut in intregime de Eula.
 *   1. oberonc compileaza modulul (intra si in biblioteca);
 *   2. clasele lui + ale bibliotecii tale + lansatorul si runtime-ul (aplicatie.jar) trec prin dx -> classes.dex;
 *   3. manifestul binar (Axml), arhiva zip si semnatura v1 (Semnatura) -> Nume.apk in casa ta.
 */
public final class Pachet {
    private Pachet() {}
    static String ultimul = "";

    public static boolean Fa(char[] fis, char[] et) {
        try {
            return fa(Dosar.f(fis), Sir.s(et).trim(), false);
        } catch (Throwable t) {
            System.out.println("n-a mers: " + Rulator.numeste(Rulator.cauza(t)));
            return false;
        }
    }

    /** v29: apk X.Mod "Nume" eula -- aplicatia are inauntru si toata Eula Oberon (luata din apk-ul ei) */
    public static boolean FaCuEula(char[] fis, char[] et) {
        try {
            return fa(Dosar.f(fis), Sir.s(et).trim(), true);
        } catch (Throwable t) {
            System.out.println("n-a mers: " + Rulator.numeste(Rulator.cauza(t)));
            return false;
        }
    }

    static boolean fa(File f, String eticheta, boolean cuEula) throws Exception {
        File apkEula = null;
        if (cuEula) {
            String a = System.getenv("EULA_APK");
            apkEula = a == null ? null : new File(a);
            if (apkEula == null || !apkEula.isFile()) {
                System.out.println("nu stiu unde e apk-ul Eulei (EULA_APK" + (a == null ? " lipseste" : " = " + a) + "): inchide terminalul si deschide-l din nou");
                return false;
            }
        }
        long t0 = System.currentTimeMillis();
        System.out.println("1/4 compilez " + f.getName());
        List<String> mods = Nucleu.compileaza(f);
        if (mods == null) return false;
        String m = mods.get(mods.size() - 1);
        Class<?> k = Class.forName(m, false, Nucleu.biblioteca());
        boolean vorbeste = false;
        try {
            k.getMethod("Apasa");
            vorbeste = true;                         // v21: aplicatie care vorbeste (Conversatie)
        } catch (NoSuchMethodException e) {
            try {
                k.getMethod("Deseneaza");
            } catch (NoSuchMethodException e2) {
                System.out.println(m + " trebuie sa exporte PROCEDURE Deseneaza*; (o cheama aplicatia la fiecare cadru, desenul trece prin Ecran)");
                System.out.println("  sau PROCEDURE Apasa*; pentru o aplicatie care vorbeste (Conversatie: casuta, butoane, raspunsuri)");
                return false;
            }
        }
        if (eticheta.isEmpty()) eticheta = m;

        System.out.println("2/4 dx: modulul, biblioteca ta si lansatorul");
        File lucru = new File(Nucleu.tmp, "apk");
        Rulator.sterge(lucru);
        File cls = new File(lucru, "clase");
        cls.mkdirs();
        dezarhiveaza(new File(Nucleu.unelte, "aplicatie.jar"), cls);       // Lansator, Ecran, Senzor, runtime Oberon
        File[] bib = new File(Nucleu.mod, Nucleu.dalvik ? "clase" : "").listFiles();
        if (bib != null) for (File d : bib) {
            if (!d.isDirectory()) continue;
            File[] c = d.listFiles();
            if (c != null) for (File x : c) if (x.getName().endsWith(".class")) Nucleu.copiaza(x, new File(cls, x.getName()));
        }
        Map<String, Boolean> dinEula = null;
        if (cuEula) {   // v29: ce e deja in codul Eulei (classes.dex al ei) nu mai intra a doua oara
            byte[] dexE = dinArhiva(apkEula, "classes.dex");
            if (dexE == null) { System.out.println("apk-ul Eulei n-are classes.dex: " + apkEula); return false; }
            dinEula = claseDex(dexE);
            List<String> ciocniri = new ArrayList<String>();
            scoateDuble(cls, cls, dinEula, ciocniri);
            List<String> rele = new ArrayList<String>(), lasate = new ArrayList<String>();
            for (String c : ciocniri) if (mods.contains(c)) rele.add(c); else lasate.add(c);
            if (!rele.isEmpty()) {
                System.out.println("modulele din " + f.getName() + " au acelasi nume cu ale Eulei: " + rele);
                System.out.println("  (Eula le are pe ale ei; da-le alt nume, apoi apk ... eula din nou)");
                return false;
            }
            if (!lasate.isEmpty()) System.out.println("   (din biblioteca ta las deoparte " + lasate + ": Eula are module cu acelasi nume)");
        }
        File dexJar = new File(lucru, "dex.jar");
        Dx.dex(Nucleu.dx(), cls, dexJar);
        byte[] dex = dinArhiva(dexJar, "classes.dex");
        if (dex == null) { System.out.println("dx n-a dat classes.dex"); return false; }

        System.out.println("3/4 manifest, arhiva, semnatura");
        String pachet = "ro.jahbalon.oberon." + m.toLowerCase().replaceAll("[^a-z0-9_]", "_") + (cuEula ? ".eula" : "");
        int versiune = (int) ((System.currentTimeMillis() / 1000 - 1767225600L) / 60);   // minute din 2026: fiecare apk e mai nou
        Map<String, byte[]> fis = new LinkedHashMap<String, byte[]>();
        Map<String, byte[]> res = new LinkedHashMap<String, byte[]>();
        int icon = Iconita.pune(res, pachet, eticheta, Iconita.propriu(f));
        if (cuEula && vorbeste) { System.out.println("apk ... eula merge doar cu aplicatii pe panza (Deseneaza), nu cu cele care vorbesc"); return false; }
        fis.put("AndroidManifest.xml", cuEula ? Axml.manifestEula(pachet, eticheta, m, versiune, icon)
            : Axml.manifest(pachet, eticheta, m, versiune, icon, vorbeste));
        fis.put(cuEula ? "classes2.dex" : "classes.dex", dex);
        fis.putAll(res);
        // v21: dosarul cu acelasi nume de langa X.Mod (X/) intra in aplicatie ca assets/ (Conversatie.Resursa)
        String baza = f.getName().replaceAll("\\.[Mm][Oo][Dd]$", "");
        File dos = new File(f.getAbsoluteFile().getParentFile(), baza);
        if (dos.isDirectory()) {
            Map<String, byte[]> pag = new LinkedHashMap<String, byte[]>();
            long[] tot = {0};
            adauga(dos, "", pag, tot);
            if (tot[0] > 150L << 20) { System.out.println("dosarul " + baza + "/ e prea mare (" + (tot[0] >> 20) + " MB, maxim 150)"); return false; }
            for (Map.Entry<String, byte[]> e : pag.entrySet()) fis.put("assets/" + e.getKey(), e.getValue());
            System.out.println("   + " + pag.size() + " fisiere din " + baza + "/ (" + (tot[0] / 1024) + " KB)");
        }
        Semnatura s = Semnatura.cheia(new File(System.getenv("EULA_SISTEM") == null ? "." : System.getenv("EULA_SISTEM")), "Eula Oberon");
        File apk = new File(Dosar.acasa, m + (cuEula ? "-eula" : "") + ".apk");
        if (cuEula) {
            ZipFile ze = new ZipFile(apkEula);
            try {
                List<String> luate = new ArrayList<String>();
                long[] cat = {0, 0};
                java.util.Enumeration<? extends ZipEntry> en = ze.entries();
                while (en.hasMoreElements()) {
                    ZipEntry e = en.nextElement();
                    String n = e.getName();
                    if (e.isDirectory() || fis.containsKey(n)) continue;
                    if (n.equals("classes.dex") || n.startsWith("lib/") || n.startsWith("assets/")) {
                        luate.add(n); cat[0]++; cat[1] += e.getSize();
                    }
                }
                System.out.println("   + Eula Oberon: " + cat[0] + " fisiere din apk-ul ei (" + (cat[1] >> 20) + " MB: codul, lib/, assets/)");
                scrieApk(apk, fis, s, ze, luate);
            } finally { ze.close(); }
        } else scrieApk(apk, fis, s);
        ultimul = apk.getAbsolutePath();
        System.out.println("4/4 gata: " + apk.getName() + " (" + (apk.length() / 1024) + " KB, pachetul " + pachet + ") in "
            + (System.currentTimeMillis() - t0) / 1000.0 + " s");
        return true;
    }

    /** v29: numele claselor dintr-un classes.dex (din class_defs), ca "ro.jahbalon.oberonapp.Lansator" */
    static Map<String, Boolean> claseDex(byte[] d) throws IOException {
        Map<String, Boolean> r = new java.util.HashMap<String, Boolean>();
        int strOff = u32(d, 0x3c), typeOff = u32(d, 0x44), nCls = u32(d, 0x60), clsOff = u32(d, 0x64);
        for (int i = 0; i < nCls; i++) {
            int tip = u32(d, clsOff + 32 * i);
            int sirIdx = u32(d, typeOff + 4 * tip);
            int p = u32(d, strOff + 4 * sirIdx);
            while ((d[p] & 0x80) != 0) p++;   // lungimea (uleb128)
            p++;
            int q = p; while (d[q] != 0) q++;
            String desc = new String(d, p, q - p, "UTF-8");   // MUTF-8: la nume de clase e la fel
            if (desc.startsWith("L") && desc.endsWith(";")) r.put(desc.substring(1, desc.length() - 1).replace('/', '.'), Boolean.TRUE);
        }
        return r;
    }

    static int u32(byte[] d, int i) { return (d[i] & 255) | (d[i + 1] & 255) << 8 | (d[i + 2] & 255) << 16 | (d[i + 3] & 255) << 24; }

    /** scoate din dosarul de clase ce are deja Eula; runtime-ul Oberon (acelasi compilator) tacut, restul = ciocniri */
    static void scoateDuble(File rad, File d, Map<String, Boolean> dinEula, List<String> ciocniri) throws IOException {
        File[] l = d.listFiles();
        if (l == null) return;
        String rp = rad.getCanonicalPath();
        for (File x : l) {
            if (x.isDirectory()) { scoateDuble(rad, x, dinEula, ciocniri); continue; }
            if (!x.getName().endsWith(".class")) continue;
            String c = x.getCanonicalPath().substring(rp.length() + 1).replace(File.separatorChar, '.');
            c = c.substring(0, c.length() - 6);
            if (!dinEula.containsKey(c)) continue;
            String baza = c.indexOf('_') > 0 ? c.substring(0, c.indexOf('_')) : c;
            if (baza.equals("OberonRuntime") || baza.equals("Files") || baza.equals("Math") || baza.equals("Out") || baza.equals("In")
                || baza.equals("Strings") || baza.equals("Os")
                || c.matches("x[^a-wyz]*")) x.delete();   // xxI, xIxV...: interfetele pe care oberonc le face pentru tipurile procedura
            else { x.delete(); if (!ciocniri.contains(baza)) ciocniri.add(baza); }
        }
    }

    static void dezarhiveaza(File jar, File in) throws IOException {
        ZipInputStream z = new ZipInputStream(new BufferedInputStream(new FileInputStream(jar)));
        ZipEntry e;
        byte[] b = new byte[65536];
        while ((e = z.getNextEntry()) != null) {
            if (e.isDirectory() || !e.getName().endsWith(".class")) continue;
            File f = new File(in, e.getName());
            if (!f.getCanonicalPath().startsWith(in.getCanonicalPath())) continue;
            f.getParentFile().mkdirs();
            OutputStream o = new FileOutputStream(f);
            int k;
            while ((k = z.read(b)) > 0) o.write(b, 0, k);
            o.close();
        }
        z.close();
    }

    static byte[] dinArhiva(File jar, String nume) throws IOException {
        ZipFile z = new ZipFile(jar);
        try {
            ZipEntry e = z.getEntry(nume);
            if (e == null) return null;
            InputStream i = z.getInputStream(e);
            ByteArrayOutputStream o = new ByteArrayOutputStream();
            byte[] b = new byte[65536];
            int k;
            while ((k = i.read(b)) > 0) o.write(b, 0, k);
            i.close();
            return o.toByteArray();
        } finally { z.close(); }
    }

    static String b64(byte[] b) {
        final String A = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        StringBuilder s = new StringBuilder();
        for (int i = 0; i < b.length; i += 3) {
            int n = (b[i] & 255) << 16 | (i + 1 < b.length ? (b[i + 1] & 255) << 8 : 0) | (i + 2 < b.length ? b[i + 2] & 255 : 0);
            s.append(A.charAt(n >> 18 & 63)).append(A.charAt(n >> 12 & 63));
            s.append(i + 1 < b.length ? A.charAt(n >> 6 & 63) : '=').append(i + 2 < b.length ? A.charAt(n & 63) : '=');
        }
        return s.toString();
    }

    static byte[] sha(byte[] b) throws Exception { return MessageDigest.getInstance("SHA-256").digest(b); }

    /** semnatura v1: MANIFEST.MF (rezumatul fiecarui fisier), CERT.SF (rezumatul manifestului), CERT.RSA (plicul) */
    static void scrieApk(File apk, Map<String, byte[]> fis, Semnatura s) throws Exception {
        StringBuilder mf = new StringBuilder("Manifest-Version: 1.0\r\nCreated-By: Eula Oberon\r\n\r\n");
        StringBuilder sf = new StringBuilder();
        List<String> sectiuni = new ArrayList<String>();
        for (Map.Entry<String, byte[]> e : fis.entrySet()) {
            String sec = "Name: " + e.getKey() + "\r\nSHA-256-Digest: " + b64(sha(e.getValue())) + "\r\n\r\n";
            mf.append(sec);
            sectiuni.add(sec);
        }
        byte[] mfb = mf.toString().getBytes("UTF-8");
        sf.append("Signature-Version: 1.0\r\nCreated-By: Eula Oberon\r\nSHA-256-Digest-Manifest: ").append(b64(sha(mfb))).append("\r\n\r\n");
        int i = 0;
        for (String nume : fis.keySet()) {
            sf.append("Name: ").append(nume).append("\r\nSHA-256-Digest: ").append(b64(sha(sectiuni.get(i++).getBytes("UTF-8")))).append("\r\n\r\n");
        }
        byte[] sfb = sf.toString().getBytes("UTF-8");
        byte[] rsa = s.pkcs7(sfb);
        File tmp = new File(apk.getPath() + ".tmp");
        ZipOutputStream z = new ZipOutputStream(new BufferedOutputStream(new FileOutputStream(tmp)));
        pune(z, "META-INF/MANIFEST.MF", mfb);
        pune(z, "META-INF/CERT.SF", sfb);
        pune(z, "META-INF/CERT.RSA", rsa);
        for (Map.Entry<String, byte[]> e : fis.entrySet()) pune(z, e.getKey(), e.getValue());
        z.close();
        apk.delete();
        if (!tmp.renameTo(apk)) throw new IOException("nu pot scrie " + apk);
    }

    /** v29: ca scrieApk, plus fisierele luate din alt apk (cel al Eulei), citite pe rand, fara sa le tin pe toate in memorie */
    static void scrieApk(File apk, Map<String, byte[]> fis, Semnatura s, ZipFile din, List<String> luate) throws Exception {
        StringBuilder mf = new StringBuilder("Manifest-Version: 1.0\r\nCreated-By: Eula Oberon\r\n\r\n");
        List<String> nume = new ArrayList<String>(), sectiuni = new ArrayList<String>();
        byte[] b = new byte[65536];
        for (Map.Entry<String, byte[]> e : fis.entrySet()) { nume.add(e.getKey()); sectiuni.add("Name: " + e.getKey() + "\r\nSHA-256-Digest: " + b64(sha(e.getValue())) + "\r\n\r\n"); }
        for (String n : luate) {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            InputStream i = din.getInputStream(din.getEntry(n));
            int k; while ((k = i.read(b)) > 0) md.update(b, 0, k);
            i.close();
            nume.add(n); sectiuni.add("Name: " + n + "\r\nSHA-256-Digest: " + b64(md.digest()) + "\r\n\r\n");
        }
        for (String sec : sectiuni) mf.append(sec);
        byte[] mfb = mf.toString().getBytes("UTF-8");
        StringBuilder sf = new StringBuilder("Signature-Version: 1.0\r\nCreated-By: Eula Oberon\r\nSHA-256-Digest-Manifest: ").append(b64(sha(mfb))).append("\r\n\r\n");
        for (int j = 0; j < nume.size(); j++)
            sf.append("Name: ").append(nume.get(j)).append("\r\nSHA-256-Digest: ").append(b64(sha(sectiuni.get(j).getBytes("UTF-8")))).append("\r\n\r\n");
        byte[] sfb = sf.toString().getBytes("UTF-8");
        byte[] rsa = s.pkcs7(sfb);
        File tmp = new File(apk.getPath() + ".tmp");
        ZipOutputStream z = new ZipOutputStream(new BufferedOutputStream(new FileOutputStream(tmp)));
        pune(z, "META-INF/MANIFEST.MF", mfb);
        pune(z, "META-INF/CERT.SF", sfb);
        pune(z, "META-INF/CERT.RSA", rsa);
        for (Map.Entry<String, byte[]> e : fis.entrySet()) pune(z, e.getKey(), e.getValue());
        for (String n : luate) {
            ZipEntry e = new ZipEntry(n);
            e.setTime(System.currentTimeMillis());
            z.putNextEntry(e);
            InputStream i = din.getInputStream(din.getEntry(n));
            int k; while ((k = i.read(b)) > 0) z.write(b, 0, k);
            i.close();
            z.closeEntry();
        }
        z.close();
        apk.delete();
        if (!tmp.renameTo(apk)) throw new IOException("nu pot scrie " + apk);
    }

    static void pune(ZipOutputStream z, String nume, byte[] b) throws IOException {
        ZipEntry e = new ZipEntry(nume);
        e.setTime(System.currentTimeMillis());
        z.putNextEntry(e);
        z.write(b);
        z.closeEntry();
    }

    // ---------------------------------------------------------------- html: o pagina HTML -> aplicatie
    // Nimic de compilat: pielea WebView (pagina.dex, facuta cand s-a construit Eula) + pagina ta in assets/,
    // manifestul si semnatura ca la apk. Plus un .zip cu index.html, gata de urcat pe itch.io.

    /** Download-ul telefonului, daca Eula are voie la el */
    static File descarcari() {
        for (String d : new String[] {"/storage/emulated/0/Download", "/sdcard/Download"}) {
            File f = new File(d);
            if (f.list() != null) return f;
        }
        return null;
    }

    public static void Acces() {
        System.out.println("Iti cer voie la fisiere (ca Eula sa vada Download/html). Apasa Permite, apoi scrie din nou comanda.");
        Nucleu.Terminal("acces;fisiere".toCharArray());
    }

    /** html Fisier.html [Nume]: una singura (din dosarul curent sau din Download/html) */
    public static boolean Html(char[] fis, char[] et) {
        try {
            String c = Sir.s(fis).trim();
            File f = Dosar.f(c);
            File d = descarcari();
            if (!f.isFile() && d != null) {
                File g = new File(new File(d, "html"), c);
                if (g.isFile()) f = g;
                else if (new File(new File(d, "html"), c + ".html").isFile()) f = new File(new File(d, "html"), c + ".html");
            }
            if (!f.isFile()) {
                System.out.println("nu gasesc " + c + (d == null ? "" : " (nici in Download/html)"));
                if (d == null) Acces();
                return false;
            }
            File apk = faPagina(f, Sir.s(et).trim(), d);
            if (apk == null) return false;
            ultimul = apk.getAbsolutePath();
            return true;
        } catch (Throwable t) {
            System.out.println("n-a mers: " + Rulator.numeste(Rulator.cauza(t)));
            return false;
        }
    }

    /** html fara nimic: toate paginile din Download/html */
    public static int Toate() {
        File d = descarcari();
        if (d == null) { Acces(); return 0; }
        File src = new File(d, "html");
        if (!src.isDirectory()) {
            src.mkdirs();
            System.out.println("Am facut dosarul Download/html. Pune HTML-urile acolo si scrie din nou html.");
            return 0;
        }
        File[] l = src.listFiles();
        if (l == null) l = new File[0];
        java.util.Arrays.sort(l);
        int n = 0, r = 0;
        for (File f : l) {
            String m = f.getName().toLowerCase();
            if (!f.isFile() || !(m.endsWith(".html") || m.endsWith(".htm"))) continue;
            if (Nucleu.Oprit()) { System.out.println("oprit"); break; }
            try {
                if (faPagina(f, "", d) != null) n++; else r++;
            } catch (Throwable t) {
                r++;
                System.out.println("  " + f.getName() + ": n-a mers: " + Rulator.numeste(Rulator.cauza(t)));
            }
        }
        if (n == 0 && r == 0) { System.out.println("Download/html e gol. Pune HTML-urile acolo si scrie din nou html."); return 0; }
        System.out.println("GATA: " + n + " aplicatii in Download/aplicatii, zip-urile pentru itch.io in Download/itch"
            + (r > 0 ? " (" + r + " n-au mers)" : ""));
        System.out.println("Le instalezi atingandu-le in Fisiere, sau aici: instaleaza nume.apk");
        return n;
    }

    static File faPagina(File f, String eticheta, File desc) throws Exception {
        String b = f.getName();
        String nume = b.lastIndexOf('.') > 0 ? b.substring(0, b.lastIndexOf('.')) : b;
        String s = nume.toLowerCase().replaceAll("[^a-z0-9]", "_");
        if (s.isEmpty() || s.charAt(0) < 'a' || s.charAt(0) > 'z') s = "a" + s;
        byte[] html = citesteTot(f);
        if (eticheta.isEmpty()) eticheta = titlu(html);
        if (eticheta.isEmpty()) eticheta = nume;

        Map<String, byte[]> fis = new LinkedHashMap<String, byte[]>();
        Map<String, byte[]> res = new LinkedHashMap<String, byte[]>();
        int icon = Iconita.pune(res, "ro.jahbalon.web." + s, eticheta, Iconita.propriu(f));
        fis.put("AndroidManifest.xml", Axml.pagina("ro.jahbalon.web." + s,
            eticheta, (int) ((System.currentTimeMillis() / 1000 - 1767225600L) / 60), icon));
        File px = new File(Nucleu.unelte, "pagina.dex");
        if (!px.isFile()) { System.out.println("lipseste pielea (" + px + "): reinstaleaza Eula"); return null; }
        fis.put("classes.dex", citesteTot(px));
        Map<String, byte[]> pag = new LinkedHashMap<String, byte[]>();   // ce merge si in zip-ul pentru itch
        pag.put("index.html", html);
        File dos = new File(f.getParentFile(), nume);   // fisierele paginii: dosarul cu acelasi nume
        long[] tot = {html.length};
        if (dos.isDirectory()) adauga(dos, nume + "/", pag, tot);
        if (tot[0] > 150L << 20) { System.out.println("  " + b + ": prea mare (" + (tot[0] >> 20) + " MB, maxim 150)"); return null; }
        for (Map.Entry<String, byte[]> e : pag.entrySet()) fis.put("assets/" + e.getKey(), e.getValue());
        fis.putAll(res);

        Semnatura sem = Semnatura.cheia(new File(System.getenv("EULA_SISTEM") == null ? "." : System.getenv("EULA_SISTEM")), "Eula Oberon");
        File apk = new File(Dosar.acasa, s + ".apk");
        scrieApk(apk, fis, sem);

        String unde = "~/" + apk.getName();
        if (desc != null) {
            File da = new File(desc, "aplicatii"), di = new File(desc, "itch");
            da.mkdirs(); di.mkdirs();
            Nucleu.copiaza(apk, new File(da, apk.getName()));
            scrieZip(new File(di, s + ".zip"), pag);
            unde = "aplicatii/" + apk.getName() + " + itch/" + s + ".zip";
        } else {
            File di = new File(Dosar.acasa, "itch");
            di.mkdirs();
            scrieZip(new File(di, s + ".zip"), pag);
            unde += " + ~/itch/" + s + ".zip";
        }
        System.out.println("  " + eticheta + "  ->  " + unde + " (" + (apk.length() / 1024) + " KB)");
        return apk;
    }

    static void adauga(File d, String pre, Map<String, byte[]> pag, long[] tot) throws IOException {
        File[] l = d.listFiles();
        if (l == null) return;
        java.util.Arrays.sort(l);
        for (File x : l) {
            if (x.isDirectory()) adauga(x, pre + x.getName() + "/", pag, tot);
            else if (x.isFile()) {
                tot[0] += x.length();
                if (tot[0] > 150L << 20) return;
                pag.put(pre + x.getName(), citesteTot(x));
            }
        }
    }

    static byte[] citesteTot(File f) throws IOException {
        InputStream i = new FileInputStream(f);
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        byte[] b = new byte[65536];
        int k;
        while ((k = i.read(b)) > 0) o.write(b, 0, k);
        i.close();
        return o.toByteArray();
    }

    /** numele din <title>, cu &amp; si prietenii lui descifrati */
    static String titlu(byte[] html) throws UnsupportedEncodingException {
        String h = new String(html, 0, Math.min(html.length, 65536), "UTF-8");
        java.util.regex.Matcher m = java.util.regex.Pattern.compile("(?is)<title[^>]*>(.*?)</title>").matcher(h);
        if (!m.find()) return "";
        String t = m.group(1).replaceAll("\\s+", " ").trim();
        java.util.regex.Matcher e = java.util.regex.Pattern.compile("&#(x?)([0-9a-fA-F]+);").matcher(t);
        StringBuffer sb = new StringBuffer();
        while (e.find()) {
            int cp;
            try { cp = Integer.parseInt(e.group(2), e.group(1).isEmpty() ? 10 : 16); } catch (NumberFormatException x) { cp = '?'; }
            e.appendReplacement(sb, java.util.regex.Matcher.quoteReplacement(new String(Character.toChars(cp))));
        }
        e.appendTail(sb);
        t = sb.toString().replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&apos;", "'")
            .replace("&nbsp;", " ").replace("&amp;", "&");
        return t.length() > 50 ? t.substring(0, 50).trim() : t;
    }

    static void scrieZip(File z, Map<String, byte[]> pag) throws IOException {
        File tmp = new File(z.getPath() + ".tmp");
        ZipOutputStream o = new ZipOutputStream(new BufferedOutputStream(new FileOutputStream(tmp)));
        for (Map.Entry<String, byte[]> e : pag.entrySet()) pune(o, e.getKey(), e.getValue());
        o.close();
        z.delete();
        if (!tmp.renameTo(z)) throw new IOException("nu pot scrie " + z);
    }

    public static void Ultimul(char[] s) { Sir.pune(ultimul, s); }

    public static void Instaleaza(char[] apk) {
        File a = Dosar.f(apk);
        if (!a.isFile()) { System.out.println("nu gasesc " + a.getPath()); return; }
        System.out.println("Android-ul te intreaba acum daca instalezi " + a.getName()
            + " (prima data: da-i Eulei voie sa instaleze aplicatii).");
        Nucleu.Terminal(("instaleaza;" + a.getAbsolutePath()).toCharArray());
    }
}
