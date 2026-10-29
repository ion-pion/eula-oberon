/** ajutor pentru punti: ARRAY OF CHAR <-> String (oberonc: char[] terminat cu 0X) */
final class Sir {
    private Sir() {}
    static String s(char[] a) {
        int k = 0;
        while (k < a.length && a[k] != 0) k++;
        return new String(a, 0, k);
    }
    static void pune(String s, char[] d) {
        if (d.length == 0) return;
        int n = Math.min(s.length(), d.length - 1);
        s.getChars(0, n, d, 0);
        d[n] = 0;
    }
}
