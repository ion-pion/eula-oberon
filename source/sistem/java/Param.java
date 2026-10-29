import java.util.ArrayList;
import java.util.List;

/** Param (vezi def/Param.Mod): cuvintele de dupa comanda */
public final class Param {
    private Param() {}
    private static String tot = "";
    private static final List<String> cuv = new ArrayList<String>();

    public static void Seteaza(char[] text) {
        tot = Sir.s(text).trim();
        cuv.clear();
        int i = 0, n = tot.length();
        while (i < n) {
            while (i < n && tot.charAt(i) <= ' ') i++;
            if (i >= n) break;
            StringBuilder b = new StringBuilder();
            if (tot.charAt(i) == '"') {
                i++;
                while (i < n && tot.charAt(i) != '"') b.append(tot.charAt(i++));
                i++;
            } else while (i < n && tot.charAt(i) > ' ') b.append(tot.charAt(i++));
            cuv.add(b.toString());
        }
    }
    public static int Nr() { return cuv.size(); }
    public static void Str(int i, char[] s) { Sir.pune(i >= 0 && i < cuv.size() ? cuv.get(i) : "", s); }
    public static boolean EInt(int i) {
        if (i < 0 || i >= cuv.size()) return false;
        try { Integer.parseInt(cuv.get(i)); return true; } catch (NumberFormatException e) { return false; }
    }
    public static int Int(int i) { return EInt(i) ? Integer.parseInt(cuv.get(i)) : 0; }
    public static void Tot(char[] s) { Sir.pune(tot, s); }
}
