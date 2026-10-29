import java.io.*;
import java.math.BigInteger;
import java.security.*;
import java.security.spec.PKCS8EncodedKeySpec;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

/**
 * Semnatura APK (schema v1, "JAR signing"), fara apksigner si fara keytool: cheia RSA si certificatul le face Eula
 * o data (le pastreaza in sistem/cheie.*), iar certificatul si plicul PKCS#7 sunt scrise octet cu octet (DER).
 */
final class Semnatura {
    final PrivateKey priv;
    final byte[] cert;         // certificatul X.509, DER
    final byte[] emitent;      // numele (Name) din certificat, pentru IssuerAndSerialNumber
    final BigInteger serie;

    private Semnatura(PrivateKey p, byte[] c, byte[] e, BigInteger s) { priv = p; cert = c; emitent = e; serie = s; }

    // ---------------------------------------------------------------- DER

    static byte[] tlv(int tag, byte[]... parti) {
        ByteArrayOutputStream c = new ByteArrayOutputStream();
        for (byte[] p : parti) c.write(p, 0, p.length);
        int n = c.size();
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        o.write(tag);
        if (n < 128) o.write(n);
        else if (n < 256) { o.write(0x81); o.write(n); }
        else if (n < 65536) { o.write(0x82); o.write(n >> 8); o.write(n & 255); }
        else { o.write(0x83); o.write(n >> 16); o.write(n >> 8 & 255); o.write(n & 255); }
        byte[] b = c.toByteArray();
        o.write(b, 0, b.length);
        return o.toByteArray();
    }
    static byte[] seq(byte[]... p) { return tlv(0x30, p); }
    static byte[] set(byte[]... p) { return tlv(0x31, p); }
    static byte[] intreg(BigInteger v) { return tlv(0x02, v.toByteArray()); }
    static byte[] nul() { return new byte[] {0x05, 0x00}; }
    static byte[] octeti(byte[] b) { return tlv(0x04, b); }
    static byte[] biti(byte[] b) { byte[] x = new byte[b.length + 1]; System.arraycopy(b, 0, x, 1, b.length); return tlv(0x03, x); }
    static byte[] utf8(String s) { try { return tlv(0x0c, s.getBytes("UTF-8")); } catch (UnsupportedEncodingException e) { throw new RuntimeException(e); } }
    static byte[] timp(Date d) {
        SimpleDateFormat f = new SimpleDateFormat("yyMMddHHmmss'Z'", Locale.US);
        f.setTimeZone(TimeZone.getTimeZone("UTC"));
        return tlv(0x17, f.format(d).getBytes());
    }
    static byte[] oid(String s) {
        String[] p = s.split("\\.");
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        o.write(Integer.parseInt(p[0]) * 40 + Integer.parseInt(p[1]));
        for (int i = 2; i < p.length; i++) {
            long v = Long.parseLong(p[i]);
            byte[] t = new byte[10];
            int k = 0;
            do { t[k++] = (byte) (v & 0x7f); v >>= 7; } while (v > 0);
            for (int j = k - 1; j >= 0; j--) o.write(t[j] | (j > 0 ? 0x80 : 0));
        }
        return tlv(0x06, o.toByteArray());
    }

    static final String SHA256 = "2.16.840.1.101.3.4.2.1", RSA = "1.2.840.113549.1.1.1", SHA256RSA = "1.2.840.113549.1.1.11",
        DATA = "1.2.840.113549.1.7.1", SIGNED = "1.2.840.113549.1.7.2", CN = "2.5.4.3", O = "2.5.4.10";

    // ---------------------------------------------------------------- cheia (o data, apoi din fisier)

    static Semnatura cheia(File dosar, String nume) throws Exception {
        File fk = new File(dosar, "cheie.pk8"), fc = new File(dosar, "cheie.crt");
        PrivateKey priv;
        byte[] cert;
        if (fk.exists() && fc.exists()) {
            priv = KeyFactory.getInstance("RSA").generatePrivate(new PKCS8EncodedKeySpec(citeste(fk)));
            cert = citeste(fc);
        } else {
            KeyPairGenerator g = KeyPairGenerator.getInstance("RSA");
            g.initialize(2048);
            KeyPair kp = g.generateKeyPair();
            priv = kp.getPrivate();
            BigInteger serie = new BigInteger(63, new SecureRandom()).add(BigInteger.ONE);
            byte[] numeDer = seq(set(seq(oid(CN), utf8(nume))), set(seq(oid(O), utf8("Jahbalon Research"))));
            byte[] alg = seq(oid(SHA256RSA), nul());
            Date de = new Date(System.currentTimeMillis() - 86400000L);
            Date pana = new SimpleDateFormat("yyyy-MM-dd", Locale.US).parse("2049-12-31");
            byte[] tbs = seq(tlv(0xa0, intreg(BigInteger.valueOf(2))), intreg(serie), alg, numeDer,
                seq(timp(de), timp(pana)), numeDer, kp.getPublic().getEncoded());
            Signature s = Signature.getInstance("SHA256withRSA");
            s.initSign(priv);
            s.update(tbs);
            cert = seq(tbs, alg, biti(s.sign()));
            dosar.mkdirs();
            scrie(fk, priv.getEncoded());
            scrie(fc, cert);
        }
        // din certificat: numele emitentului si seria (pentru plicul PKCS#7)
        Der c = new Der(cert, 0).copil(0);           // Certificate -> TBSCertificate
        int i = 0;
        Der x = c.copil(i);
        if ((x.tag & 0xff) == 0xa0) x = c.copil(++i);  // versiunea
        BigInteger serie = new BigInteger(x.continut());
        Der emitent = c.copil(i + 2);
        return new Semnatura(priv, cert, emitent.tot(), serie);
    }

    /** cititor DER minimal: cat trebuie ca sa scot campurile din certificat */
    static final class Der {
        final byte[] b; final int start, tag, cap, len;
        Der(byte[] b, int start) {
            this.b = b; this.start = start; tag = b[start] & 0xff;
            int l = b[start + 1] & 0xff, p = start + 2;
            if (l >= 0x80) { int k = l & 0x7f; l = 0; for (int j = 0; j < k; j++) l = l << 8 | (b[p++] & 0xff); }
            cap = p; len = l;
        }
        Der copil(int n) { int p = cap; Der d = new Der(b, p); for (int i = 0; i < n; i++) { p = d.cap + d.len; d = new Der(b, p); } return d; }
        byte[] continut() { byte[] r = new byte[len]; System.arraycopy(b, cap, r, 0, len); return r; }
        byte[] tot() { byte[] r = new byte[cap + len - start]; System.arraycopy(b, start, r, 0, r.length); return r; }
    }

    static byte[] citeste(File f) throws IOException {
        InputStream i = new FileInputStream(f);
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        byte[] b = new byte[8192];
        int k;
        while ((k = i.read(b)) > 0) o.write(b, 0, k);
        i.close();
        return o.toByteArray();
    }
    static void scrie(File f, byte[] b) throws IOException { OutputStream o = new FileOutputStream(f); o.write(b); o.close(); }

    // ---------------------------------------------------------------- semnatura v1

    /** plicul PKCS#7 SignedData (detasat) pentru CERT.SF */
    byte[] pkcs7(byte[] sf) throws Exception {
        Signature s = Signature.getInstance("SHA256withRSA");
        s.initSign(priv);
        s.update(sf);
        byte[] semn = s.sign();
        byte[] signer = seq(intreg(BigInteger.ONE), seq(emitent, intreg(serie)), seq(oid(SHA256), nul()),
            seq(oid(RSA), nul()), octeti(semn));
        byte[] sd = seq(intreg(BigInteger.ONE), set(seq(oid(SHA256), nul())), seq(oid(DATA)),
            tlv(0xa0, cert), set(signer));
        return seq(oid(SIGNED), tlv(0xa0, sd));
    }
}
