import java.io.File;
import java.io.FileDescriptor;
import java.io.FileOutputStream;
import java.io.PrintStream;

/**
 * Pornirea sistemului Eula: pregateste iesirea (UTF-8, fara tampon, ca promptul sa apara pe loc), dosarele si
 * nucleul, apoi da controlul shell-ului, care e scris in Oberon (Shell.Mod).
 * Ruleaza cu dalvikvm in terminalul Eulei; pe calculator merge si cu java (fara dx).
 */
public final class EulaSistem {
    private EulaSistem() {}

    public static void main(String[] a) throws Exception {
        System.setOut(new PrintStream(new FileOutputStream(FileDescriptor.out), true, "UTF-8"));
        System.setErr(System.out);
        String home = env("HOME", System.getProperty("user.dir", "/"));
        Dosar.acasa = new File(home);
        Dosar.curent = new File(home);
        Nucleu.init(new File(env("EULA_UNELTE", ".")), new File(env("EULA_SISTEM", home + "/.sistem")));
        final Class<?> shell = Class.forName("Shell");
        Thread t = new Thread(null, new Runnable() { public void run() {
            try { shell.getMethod("Porneste").invoke(null); }
            catch (Throwable x) { System.out.println("shell-ul a căzut: " + ro.jahbalon.eulaoberon.Rulator.numeste(ro.jahbalon.eulaoberon.Rulator.cauza(x))); }
        }}, "shell", 64L << 20);
        t.start();
        t.join();
        System.out.flush();
        System.exit(0);
    }

    static String env(String k, String implicit) {
        String v = System.getenv(k);
        return v == null || v.isEmpty() ? implicit : v;
    }
}
