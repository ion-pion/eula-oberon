package ro.jahbalon.oberonapp;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.Charset;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Plasa (pentru Conversatie.Aduce): aduce o adresa prin retea, ca un om care deschide pagina. Urmeaza
 * redirectionarile (si de la http la https), se prezinta cinstit (EulaOberon), si scrie corpul intr-un fisier, ca text
 * UTF-8 (daca pagina e in alta codare, o trece in UTF-8). Doar transportul e aici; ce inseamna pagina vede Oberon.
 */
public final class Plasa {
    private Plasa() {}
    public static final String AGENT = "EulaOberon/22 (Jahbalon Research; https://github.com/ion-pion)";
    static final int MAX = 8 << 20;
    public static String finala = "", tip = "";

    /** spatiile si literele ne-ASCII din adresa -> %XX (UTF-8), cum le cere HTTP */
    static String ascii(String a) {
        StringBuilder b = new StringBuilder();
        try {
            for (int i = 0; i < a.length(); i++) {
                char c = a.charAt(i);
                if (c > 32 && c < 127) b.append(c);
                else for (byte x : String.valueOf(c).getBytes("UTF-8")) b.append('%').append(String.format("%02X", x & 255));
            }
        } catch (UnsupportedEncodingException e) { return a; }
        return b.toString();
    }

    static final Pattern CS = Pattern.compile("(?i)charset\\s*=\\s*[\"']?([A-Za-z0-9_\\-:.]+)");

    /** intoarce codul HTTP (-1 = fara retea); corpul, in UTF-8, in fisierul cale */
    public static int aduce(String adresa, String cale) {
        finala = adresa; tip = "";
        HttpURLConnection c = null;
        try {
            String a = ascii(adresa);
            int cod = -1;
            for (int salt = 0; salt < 6; salt++) {
                c = (HttpURLConnection) new URL(a).openConnection();
                c.setInstanceFollowRedirects(false);
                c.setConnectTimeout(15000);
                c.setReadTimeout(30000);
                c.setRequestProperty("User-Agent", AGENT);
                c.setRequestProperty("Accept", "text/html,text/plain;q=0.9,*/*;q=0.5");
                c.setRequestProperty("Accept-Language", "ro,en;q=0.5");
                cod = c.getResponseCode();
                if (cod >= 300 && cod < 400 && c.getHeaderField("Location") != null) {
                    a = ascii(new URL(new URL(a), c.getHeaderField("Location")).toString());
                    c.disconnect();
                    continue;
                }
                break;
            }
            finala = a;
            tip = c.getContentType() == null ? "" : c.getContentType();
            InputStream in = cod >= 400 ? c.getErrorStream() : c.getInputStream();
            ByteArrayOutputStream o = new ByteArrayOutputStream();
            if (in != null) {
                byte[] b = new byte[65536];
                int k;
                while ((k = in.read(b)) > 0 && o.size() < MAX) o.write(b, 0, k);
                in.close();
            }
            byte[] corp = o.toByteArray();
            // codarea: din antet, altfel din <meta charset> (primii 4 KB), altfel UTF-8
            String cs = null;
            Matcher m = CS.matcher(tip);
            if (m.find()) cs = m.group(1);
            if (cs == null) {
                m = CS.matcher(new String(corp, 0, Math.min(corp.length, 4096), "ISO-8859-1"));
                if (m.find()) cs = m.group(1);
            }
            if (cs != null && !cs.equalsIgnoreCase("utf-8") && !cs.equalsIgnoreCase("utf8")) {
                try { corp = new String(corp, Charset.forName(cs)).getBytes("UTF-8"); } catch (Exception e) { /* raman octetii */ }
            }
            OutputStream f = new FileOutputStream(cale);
            f.write(corp);
            f.close();
            return cod;
        } catch (Throwable t) {
            return -1;
        } finally {
            if (c != null) c.disconnect();
        }
    }
}
