import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.zip.CRC32;
import java.util.zip.Deflater;

/**
 * Iconita aplicatiilor facute de Eula (apk si html), desenata aici, fara aapt2 si fara Android:
 *   - desenul: un cub Eula pe un fond colorat dupa nume, cu initialele dedesubt (litere 5x7, netezite);
 *   - PNG-ul il scriem de mana (zlib + CRC32 din java.util.zip);
 *   - resources.arsc (tabelul de resurse) il scriem tot de mana, ca Axml pentru manifest.
 * Pe Android 8+ iconita e adaptiva (fond + fata, launcher-ul ii da forma), pe cele vechi e PNG-ul intreg.
 * Daca langa sursa ai un Nume.png (langa Nume.html sau Nume.Mod), Eula il pune pe acela.
 */
final class Iconita {
    private Iconita() {}

    static final String DRUM_ICON = "res/drawable-xxxhdpi-v4/icon.png";
    static final String DRUM_FATA = "res/drawable-xxxhdpi-v4/fata.png";
    static final String DRUM_FOND = "res/drawable-xxxhdpi-v4/fond.png";
    static final String DRUM_ADAPTIV = "res/mipmap-anydpi-v26/iconita.xml";
    static final int ID_ICON = 0x7f010000, ID_FATA = 0x7f010001, ID_FOND = 0x7f010002, ID_ADAPTIV = 0x7f020000;

    /**
     * Pune in fis iconita si tabelul de resurse; intoarce id-ul de pus in manifest (android:icon).
     * @param propriu PNG-ul tau (null = o desenez eu)
     */
    static int pune(Map<String, byte[]> fis, String pachet, String eticheta, byte[] propriu) throws IOException {
        if (propriu != null) {
            fis.put(DRUM_ICON, propriu);
            fis.put("resources.arsc", arsc(pachet, false));
            return ID_ICON;
        }
        float h = nuanta(pachet);
        String in = initiale(eticheta);
        fis.put(DRUM_ICON, png(192, deseneaza(192, h, in, Strat.TOT)));
        fis.put(DRUM_FATA, png(432, deseneaza(432, h, in, Strat.FATA)));
        fis.put(DRUM_FOND, png(432, deseneaza(432, h, in, Strat.FOND)));
        fis.put(DRUM_ADAPTIV, Axml.iconitaAdaptiva(ID_FOND, ID_FATA));
        fis.put("resources.arsc", arsc(pachet, true));
        return ID_ADAPTIV;
    }

    /** Nume.png langa sursa, daca e chiar PNG */
    static byte[] propriu(File sursa) {
        String b = sursa.getName();
        String nume = b.lastIndexOf('.') > 0 ? b.substring(0, b.lastIndexOf('.')) : b;
        File p = new File(sursa.getParentFile(), nume + ".png");
        if (!p.isFile() || p.length() > (4 << 20)) return null;
        try {
            FileInputStream i = new FileInputStream(p);
            ByteArrayOutputStream o = new ByteArrayOutputStream();
            byte[] buf = new byte[65536];
            int k;
            while ((k = i.read(buf)) > 0) o.write(buf, 0, k);
            i.close();
            byte[] d = o.toByteArray();
            return d.length > 8 && (d[0] & 255) == 0x89 && d[1] == 'P' && d[2] == 'N' && d[3] == 'G' ? d : null;
        } catch (IOException e) { return null; }
    }

    // ================================================================ desenul

    enum Strat { TOT, FATA, FOND }

    static float nuanta(String s) {
        int h = 7;
        for (int i = 0; i < s.length(); i++) h = h * 31 + s.charAt(i);
        return ((h & 0x7fffffff) % 360) / 360f;
    }

    /** initialele: prima litera din primele doua cuvinte (fara diacritice), sau prima litera daca e un singur cuvant */
    static String initiale(String eticheta) {
        String t = java.text.Normalizer.normalize(eticheta, java.text.Normalizer.Form.NFD).toUpperCase();
        StringBuilder b = new StringBuilder();
        boolean inCuvant = false;
        for (int i = 0; i < t.length() && b.length() < 2; i++) {
            char c = t.charAt(i);
            boolean bun = (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9');
            if (Character.getType(c) == Character.NON_SPACING_MARK) continue;
            if (bun && !inCuvant) b.append(c);
            inCuvant = bun || (inCuvant && Character.isLetterOrDigit(c));
        }
        return b.length() == 0 ? "E" : b.toString();
    }

    static int hsv(float h, float s, float v) {
        float r, g, bl;
        float x = h * 6f;
        int i = (int) Math.floor(x) % 6;
        float f = x - (float) Math.floor(x), p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s);
        switch (i) {
            case 0: r = v; g = t; bl = p; break;
            case 1: r = q; g = v; bl = p; break;
            case 2: r = p; g = v; bl = t; break;
            case 3: r = p; g = q; bl = v; break;
            case 4: r = t; g = p; bl = v; break;
            default: r = v; g = p; bl = q;
        }
        return (Math.round(r * 255) << 16) | (Math.round(g * 255) << 8) | Math.round(bl * 255);
    }

    /** literele 5x7 (randuri de sus in jos, 5 biti fiecare) */
    static final String LITERE = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    static final int[][] FONT = {
        {14,17,17,31,17,17,17},{30,17,17,30,17,17,30},{14,17,16,16,16,17,14},{30,17,17,17,17,17,30},
        {31,16,16,30,16,16,31},{31,16,16,30,16,16,16},{14,17,16,23,17,17,15},{17,17,17,31,17,17,17},
        {14,4,4,4,4,4,14},{7,2,2,2,2,18,12},{17,18,20,24,20,18,17},{16,16,16,16,16,16,31},
        {17,27,21,21,17,17,17},{17,17,25,21,19,17,17},{14,17,17,17,17,17,14},{30,17,17,30,16,16,16},
        {14,17,17,17,21,18,13},{30,17,17,30,20,18,17},{15,16,16,14,1,1,30},{31,4,4,4,4,4,4},
        {17,17,17,17,17,17,14},{17,17,17,17,17,10,4},{17,17,17,21,21,21,10},{17,17,10,4,10,17,17},
        {17,17,10,4,4,4,4},{31,1,2,4,8,16,31},
        {14,17,19,21,25,17,14},{4,12,4,4,4,4,14},{14,17,1,2,4,8,31},{31,2,4,2,1,17,14},
        {2,6,10,18,31,2,2},{31,16,30,1,1,17,14},{6,8,16,30,17,17,14},{31,1,2,4,8,8,8},
        {14,17,17,14,17,17,14},{14,17,17,15,1,2,12}};

    /** desenul in coordonate 0..1; intoarce culoarea ARGB a punctului (x, y) */
    static final class Scena {
        final int fond1, fond2;
        final float[][] fete;          // 3 patrulatere: x0,y0,x1,y1,x2,y2,x3,y3
        final int[] culoriFete = {0xF2CE7A, 0xC9A85E, 0x8E6E36};
        final float[] muchii;          // segmente x0,y0,x1,y1 ...
        final float grosime;
        final List<float[]> pixeliLitere = new ArrayList<float[]>();   // dreptunghiuri x, y, w, h
        final boolean fond, fata, rotunjit;

        Scena(float h, String in, boolean fond, boolean fata, boolean rotunjit) {
            this.fond = fond; this.fata = fata; this.rotunjit = rotunjit;
            fond1 = hsv(h, 0.55f, 0.34f);
            fond2 = hsv((h + 0.06f) % 1f, 0.70f, 0.13f);
            float cx = 0.5f, cy = 0.41f, s = 0.235f, w = s * 0.866f;
            float[] sus = {cx, cy - s}, dr = {cx + w, cy - s / 2}, mij = {cx, cy}, st = {cx - w, cy - s / 2};
            float[] drJ = {dr[0], dr[1] + s}, mijJ = {cx, cy + s}, stJ = {st[0], st[1] + s};
            fete = new float[][] {
                {sus[0], sus[1], dr[0], dr[1], mij[0], mij[1], st[0], st[1]},
                {st[0], st[1], mij[0], mij[1], mijJ[0], mijJ[1], stJ[0], stJ[1]},
                {mij[0], mij[1], dr[0], dr[1], drJ[0], drJ[1], mijJ[0], mijJ[1]}};
            muchii = new float[] {sus[0], sus[1], dr[0], dr[1], dr[0], dr[1], drJ[0], drJ[1], drJ[0], drJ[1], mijJ[0], mijJ[1],
                mijJ[0], mijJ[1], stJ[0], stJ[1], stJ[0], stJ[1], st[0], st[1], st[0], st[1], sus[0], sus[1],
                st[0], st[1], mij[0], mij[1], mij[0], mij[1], dr[0], dr[1], mij[0], mij[1], mijJ[0], mijJ[1]};
            grosime = 0.012f;
            // initialele: inaltime 0.15, centrate pe x, sub cub
            float hl = 0.15f, cel = hl / 7f, spatiu = cel;
            float lat = in.length() * 5 * cel + (in.length() - 1) * spatiu;
            float x0 = 0.5f - lat / 2, y0 = 0.70f;
            for (int k = 0; k < in.length(); k++) {
                int idx = LITERE.indexOf(in.charAt(k));
                if (idx < 0) continue;
                for (int r = 0; r < 7; r++)
                    for (int c = 0; c < 5; c++)
                        if ((FONT[idx][r] >> (4 - c) & 1) != 0)
                            pixeliLitere.add(new float[] {x0 + k * (5 * cel + spatiu) + c * cel, y0 + r * cel, cel * 1.02f, cel * 1.02f});
            }
        }

        static boolean inPatrulater(float[] q, float x, float y) {
            boolean poz = false, neg = false;
            for (int i = 0; i < 4; i++) {
                float ax = q[i * 2], ay = q[i * 2 + 1], bx = q[(i * 2 + 2) % 8], by = q[(i * 2 + 3) % 8];
                float d = (bx - ax) * (y - ay) - (by - ay) * (x - ax);
                if (d > 0) poz = true; else if (d < 0) neg = true;
            }
            return !(poz && neg);
        }

        static float distSegment(float px, float py, float ax, float ay, float bx, float by) {
            float dx = bx - ax, dy = by - ay, t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
            t = Math.max(0, Math.min(1, t));
            float ex = ax + t * dx - px, ey = ay + t * dy - py;
            return (float) Math.sqrt(ex * ex + ey * ey);
        }

        /** ARGB in punctul (x, y), 0..1 */
        int culoare(float x, float y) {
            int c = 0;   // transparent
            if (fond) {
                boolean in = true;
                if (rotunjit) {
                    float r = 0.18f, m = 0.04f;
                    float qx = Math.max(Math.abs(x - 0.5f) - (0.5f - m - r), 0), qy = Math.max(Math.abs(y - 0.5f) - (0.5f - m - r), 0);
                    in = qx * qx + qy * qy <= r * r;
                }
                if (in) c = 0xFF000000 | amesteca(fond1, fond2, Math.max(0, Math.min(1, y)));
            }
            if (fata) {
                for (int i = 0; i < 3; i++) if (inPatrulater(fete[i], x, y)) c = 0xFF000000 | culoriFete[i];
                for (int i = 0; i < muchii.length; i += 4)
                    if (distSegment(x, y, muchii[i], muchii[i + 1], muchii[i + 2], muchii[i + 3]) < grosime / 2) { c = 0xFF3A2410; break; }
                for (float[] p : pixeliLitere)
                    if (x >= p[0] && x < p[0] + p[2] && y >= p[1] && y < p[1] + p[3]) { c = 0xFFF6EBCF; break; }
            }
            return c;
        }
    }

    static int amesteca(int a, int b, float t) {
        int r = Math.round(((a >> 16) & 255) * (1 - t) + ((b >> 16) & 255) * t);
        int g = Math.round(((a >> 8) & 255) * (1 - t) + ((b >> 8) & 255) * t);
        int bl = Math.round((a & 255) * (1 - t) + (b & 255) * t);
        return r << 16 | g << 8 | bl;
    }

    /** pixelii RGBA ai iconitei; FATA e desenata in zona sigura a iconitei adaptive (cercul din mijloc, 66/108) */
    static byte[] deseneaza(int n, float h, String in, Strat strat) {
        Scena sc = new Scena(h, in, strat != Strat.FATA, false, strat == Strat.TOT);   // fata o deseneaza culoareFata
        float scara, dep;
        if (strat == Strat.FATA) { scara = 0.60f; dep = 0.20f; }       // fata adaptiva: in cercul sigur
        else if (strat == Strat.TOT) { scara = 0.86f; dep = 0.07f; }   // iconita veche: cubul in patratul rotunjit
        else { scara = 1f; dep = 0f; }
        int ss = strat == Strat.FOND ? 1 : 4;   // netezire: 4x4 esantioane pe pixel
        byte[] px = new byte[n * n * 4];
        for (int y = 0; y < n; y++)
            for (int x = 0; x < n; x++) {
                float a = 0, r = 0, g = 0, b = 0;
                for (int sy = 0; sy < ss; sy++)
                    for (int sx = 0; sx < ss; sx++) {
                        float ux = (x + (sx + 0.5f) / ss) / n, uy = (y + (sy + 0.5f) / ss) / n;
                        int c;
                        if (strat == Strat.TOT) {
                            c = sc.culoare(ux, uy);                       // fondul rotunjit pe tot patratul
                            if (c != 0) {                                 // cubul si literele, micsorate in patrat
                                int cf = culoareFata(sc, (ux - dep) / scara, (uy - dep) / scara);
                                if (cf != 0) c = cf;
                            }
                        } else if (strat == Strat.FATA) c = culoareFata(sc, (ux - dep) / scara, (uy - dep) / scara);
                        else c = sc.culoare(ux, uy);
                        float ca = ((c >>> 24) & 255) / 255f;
                        a += ca; r += ((c >> 16) & 255) * ca; g += ((c >> 8) & 255) * ca; b += (c & 255) * ca;
                    }
                int k = (y * n + x) * 4, m = ss * ss;
                if (a > 0) { px[k] = (byte) Math.round(r / a); px[k + 1] = (byte) Math.round(g / a); px[k + 2] = (byte) Math.round(b / a); }
                px[k + 3] = (byte) Math.round(a / m * 255);
            }
        return px;
    }

    /** doar cubul si literele (fara fond) */
    static int culoareFata(Scena sc, float x, float y) {
        int c = 0;
        for (int i = 0; i < 3; i++) if (Scena.inPatrulater(sc.fete[i], x, y)) c = 0xFF000000 | sc.culoriFete[i];
        for (int i = 0; i < sc.muchii.length; i += 4)
            if (Scena.distSegment(x, y, sc.muchii[i], sc.muchii[i + 1], sc.muchii[i + 2], sc.muchii[i + 3]) < sc.grosime / 2) { c = 0xFF3A2410; break; }
        for (float[] p : sc.pixeliLitere)
            if (x >= p[0] && x < p[0] + p[2] && y >= p[1] && y < p[1] + p[3]) { c = 0xFFF6EBCF; break; }
        return c;
    }

    // ================================================================ PNG

    static byte[] png(int n, byte[] rgba) throws IOException {
        ByteArrayOutputStream brut = new ByteArrayOutputStream(n * (n * 4 + 1));
        for (int y = 0; y < n; y++) { brut.write(0); brut.write(rgba, y * n * 4, n * 4); }   // filtrul 0 pe fiecare rand
        Deflater d = new Deflater(9);
        d.setInput(brut.toByteArray());
        d.finish();
        ByteArrayOutputStream z = new ByteArrayOutputStream();
        byte[] buf = new byte[65536];
        while (!d.finished()) { int k = d.deflate(buf); z.write(buf, 0, k); }
        d.end();
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        o.write(new byte[] {(byte) 0x89, 'P', 'N', 'G', 13, 10, 26, 10});
        ByteArrayOutputStream ihdr = new ByteArrayOutputStream();
        be32(ihdr, n); be32(ihdr, n);
        ihdr.write(8); ihdr.write(6); ihdr.write(0); ihdr.write(0); ihdr.write(0);   // 8 biti, RGBA
        bucata(o, "IHDR", ihdr.toByteArray());
        bucata(o, "IDAT", z.toByteArray());
        bucata(o, "IEND", new byte[0]);
        return o.toByteArray();
    }

    static void be32(ByteArrayOutputStream o, int v) { o.write(v >>> 24); o.write(v >>> 16 & 255); o.write(v >>> 8 & 255); o.write(v & 255); }

    static void bucata(ByteArrayOutputStream o, String tip, byte[] date) throws IOException {
        be32(o, date.length);
        byte[] t = tip.getBytes("US-ASCII");
        o.write(t);
        o.write(date);
        CRC32 c = new CRC32();
        c.update(t);
        c.update(date);
        be32(o, (int) c.getValue());
    }

    // ================================================================ resources.arsc

    private static void u16(ByteArrayOutputStream o, int v) { o.write(v & 255); o.write(v >> 8 & 255); }
    private static void u32(ByteArrayOutputStream o, int v) { u16(o, v); u16(o, v >>> 16); }

    /** un tabel de siruri UTF-16 (ResStringPool) */
    static byte[] siruri(String... s) throws UnsupportedEncodingException {
        ByteArrayOutputStream date = new ByteArrayOutputStream();
        int[] poz = new int[s.length];
        for (int i = 0; i < s.length; i++) {
            poz[i] = date.size();
            u16(date, s[i].length());
            byte[] b = s[i].getBytes("UTF-16LE");
            date.write(b, 0, b.length);
            u16(date, 0);
        }
        while (date.size() % 4 != 0) date.write(0);
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        int start = 28 + 4 * s.length;
        u16(o, 0x0001); u16(o, 28); u32(o, start + date.size());
        u32(o, s.length); u32(o, 0); u32(o, 0); u32(o, start); u32(o, 0);
        for (int p : poz) u32(o, p);
        byte[] d = date.toByteArray();
        o.write(d, 0, d.length);
        return o.toByteArray();
    }

    /** configuratia (ResTable_config, 64 de octeti): doar densitatea si versiunea minima de Android */
    static byte[] config(int densitate, int sdk) {
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        u32(o, 64);
        u32(o, 0);                  // mcc, mnc
        u32(o, 0);                  // limba, tara
        o.write(0); o.write(0);     // orientare, ecran tactil
        u16(o, densitate);          // densitatea
        u32(o, 0);                  // tastatura, navigare, inputFlags, pad
        u32(o, 0);                  // latime, inaltime ecran
        u16(o, sdk); u16(o, 0);     // sdkVersion, minorVersion
        while (o.size() < 64) o.write(0);
        return o.toByteArray();
    }

    /** o valoare: sir (cale de fisier, indice in tabelul global) sau referinta la alta resursa */
    static final int V_REF = 0x01, V_SIR = 0x03;

    /** ResTable_type: o configuratie a unui tip, cu valorile intrarilor (null = intrarea lipseste aici) */
    static byte[] tip(int id, byte[] config, int[][] valori) {
        int n = valori.length;
        ByteArrayOutputStream intrari = new ByteArrayOutputStream();
        int[] off = new int[n];
        for (int i = 0; i < n; i++) {
            if (valori[i] == null) { off[i] = -1; continue; }
            off[i] = intrari.size();
            u16(intrari, 8); u16(intrari, 0); u32(intrari, valori[i][0]);           // ResTable_entry: cheia
            u16(intrari, 8); intrari.write(0); intrari.write(valori[i][1]); u32(intrari, valori[i][2]);   // Res_value
        }
        int antet = 20 + config.length, start = antet + 4 * n;
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        u16(o, 0x0201); u16(o, antet); u32(o, start + intrari.size());
        o.write(id); o.write(0); u16(o, 0);
        u32(o, n); u32(o, start);
        o.write(config, 0, config.length);
        for (int x : off) u32(o, x);
        byte[] d = intrari.toByteArray();
        o.write(d, 0, d.length);
        return o.toByteArray();
    }

    static byte[] specificatie(int id, int[] steaguri) {
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        u16(o, 0x0202); u16(o, 16); u32(o, 16 + 4 * steaguri.length);
        o.write(id); o.write(0); u16(o, 0);
        u32(o, steaguri.length);
        for (int s : steaguri) u32(o, s);
        return o.toByteArray();
    }

    static final int CONFIG_DENSITY = 0x0100, CONFIG_VERSION = 0x0400;

    /**
     * Tabelul de resurse. Adaptiv: drawable/icon (192px), drawable/fata, drawable/fond (432px), toate xxxhdpi;
     * mipmap/iconita = iconita adaptiva pe Android 8+ (anydpi-v26) si @drawable/icon in rest.
     * Altfel: doar drawable/icon (PNG-ul tau).
     */
    static byte[] arsc(String pachet, boolean adaptiv) throws IOException {
        String[] globale = adaptiv ? new String[] {DRUM_ICON, DRUM_FATA, DRUM_FOND, DRUM_ADAPTIV} : new String[] {DRUM_ICON};
        byte[] sg = siruri(globale);
        byte[] tipuri = adaptiv ? siruri("drawable", "mipmap") : siruri("drawable");
        byte[] chei = adaptiv ? siruri("icon", "fata", "fond", "iconita") : siruri("icon");
        ByteArrayOutputStream corp = new ByteArrayOutputStream();
        byte[] xxxhdpi = config(640, 4);
        if (adaptiv) {
            byte[] b;
            b = specificatie(1, new int[] {CONFIG_DENSITY, CONFIG_DENSITY, CONFIG_DENSITY}); corp.write(b, 0, b.length);
            b = tip(1, xxxhdpi, new int[][] {{0, V_SIR, 0}, {1, V_SIR, 1}, {2, V_SIR, 2}}); corp.write(b, 0, b.length);
            b = specificatie(2, new int[] {CONFIG_DENSITY | CONFIG_VERSION}); corp.write(b, 0, b.length);
            b = tip(2, config(0, 0), new int[][] {{3, V_REF, ID_ICON}}); corp.write(b, 0, b.length);
            b = tip(2, config(0xfffe, 26), new int[][] {{3, V_SIR, 3}}); corp.write(b, 0, b.length);
        } else {
            byte[] b;
            b = specificatie(1, new int[] {CONFIG_DENSITY}); corp.write(b, 0, b.length);
            b = tip(1, xxxhdpi, new int[][] {{0, V_SIR, 0}}); corp.write(b, 0, b.length);
        }
        // pachetul
        int antetP = 288;
        ByteArrayOutputStream p = new ByteArrayOutputStream();
        u16(p, 0x0200); u16(p, antetP); u32(p, antetP + tipuri.length + chei.length + corp.size());
        u32(p, 0x7f);
        byte[] nume = pachet.getBytes("UTF-16LE");
        for (int i = 0; i < 256; i++) p.write(i < nume.length && i < 254 ? nume[i] : 0);
        u32(p, antetP);                          // tabelul tipurilor
        u32(p, adaptiv ? 2 : 1);                 // ultimul tip public
        u32(p, antetP + tipuri.length);          // tabelul cheilor
        u32(p, adaptiv ? 4 : 1);                 // ultima cheie publica
        u32(p, 0);                               // typeIdOffset
        p.write(tipuri, 0, tipuri.length);
        p.write(chei, 0, chei.length);
        byte[] c = corp.toByteArray();
        p.write(c, 0, c.length);
        // tabelul intreg
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        u16(o, 0x0002); u16(o, 12); u32(o, 12 + sg.length + p.size());
        u32(o, 1);
        o.write(sg, 0, sg.length);
        byte[] pb = p.toByteArray();
        o.write(pb, 0, pb.length);
        return o.toByteArray();
    }
}
