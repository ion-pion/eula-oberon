import java.io.File;
import java.io.FileInputStream;

/**
 * Senzor (vezi def/Senzor.Mod). Sistemul ruleaza intr-o masina Java fara acces la senzori, asa ca ii cere ecranului
 * (prin secventa OSC 7777, ca la edit) sa citeasca busola; ecranul scrie azimutul intr-un fisier mic, de aici citit.
 */
public final class Senzor {
    private Senzor() {}

    static File fisier() {
        String s = System.getenv("EULA_SISTEM");
        return new File(s == null ? "." : s, "senzor-busola");
    }

    public static boolean Porneste() {
        File f = fisier();
        f.delete();
        System.out.print("\033]7777;senzor;busola\007");
        System.out.flush();
        for (int i = 0; i < 40 && !f.exists(); i++) Nucleu.Asteapta(50);   // ecranul raspunde in cateva zecimi
        return Azimut() != -2;
    }

    /** -1 = inca nu stiu, -2 = telefonul n-are busola */
    public static int Azimut() {
        try {
            FileInputStream i = new FileInputStream(fisier());
            byte[] b = new byte[16];
            int n = i.read(b);
            i.close();
            return n > 0 ? Integer.parseInt(new String(b, 0, n, "US-ASCII").trim()) : -1;
        } catch (Exception e) {
            return -1;
        }
    }

    /** in terminal nu am gravitatia: ea merge in aplicatiile facute cu apk */
    public static boolean PornesteGravitatia() { return false; }
    public static int GX() { return 0; }
    public static int GY() { return 0; }
    public static int GZ() { return 0; }
    public static boolean PornesteMiscarea() { return false; }
    public static int Sus() { return 0; }
    public static int LX() { return 0; }
    public static int LY() { return 0; }
    public static int LZ() { return 0; }

    public static void Opreste() {
        System.out.print("\033]7777;senzor;oprit\007");
        System.out.flush();
    }
}
