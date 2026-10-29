import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;

/** Retea (vezi def/Retea.Mod): descarcari HTTP(S), urmand redirectionarile */
public final class Retea {
    private Retea() {}
    private static String eroare = "";

    public static int Descarca(char[] u, char[] fis) {
        eroare = "";
        String adresa = Sir.s(u);
        File in = Dosar.f(fis);
        try {
            for (int salt = 0; salt < 8; salt++) {
                HttpURLConnection c = (HttpURLConnection) new URL(adresa).openConnection();
                c.setInstanceFollowRedirects(false);
                c.setConnectTimeout(20000);
                c.setReadTimeout(60000);
                c.setRequestProperty("User-Agent", "EulaOberon");
                int cod = c.getResponseCode();
                if (cod >= 300 && cod < 400) {
                    String loc = c.getHeaderField("Location");
                    c.disconnect();
                    if (loc == null) { eroare = "redirecționare fără adresă"; return -1; }
                    adresa = new URL(new URL(adresa), loc).toString();
                    continue;
                }
                if (cod != 200) { eroare = "serverul a răspuns " + cod; c.disconnect(); return -cod; }
                long tot = c.getContentLength();
                InputStream i = c.getInputStream();
                File tmp = new File(in.getPath() + ".part");
                OutputStream o = new FileOutputStream(tmp);
                byte[] b = new byte[65536];
                long n = 0, urm = 1 << 20;
                int k;
                while ((k = i.read(b)) > 0) {
                    o.write(b, 0, k);
                    n += k;
                    if (n >= urm) { System.out.print("\r  " + (n >> 20) + " MB" + (tot > 0 ? " din " + (tot >> 20) + " MB" : "") + "  "); urm = n + (1 << 20); }
                }
                o.close(); i.close();
                if (n >= (1 << 20)) System.out.print("\r\n");
                if (tot > 0 && n != tot) { eroare = "s-a rupt la " + n + " din " + tot; tmp.delete(); return -2; }
                in.delete();
                if (!tmp.renameTo(in)) { eroare = "nu pot scrie " + in; return -3; }
                return n > Integer.MAX_VALUE ? Integer.MAX_VALUE : (int) n;
            }
            eroare = "prea multe redirecționări";
            return -4;
        } catch (IOException e) {
            eroare = e.toString();
            return -5;
        }
    }
    public static void Eroare(char[] s) { Sir.pune(eroare, s); }
}
