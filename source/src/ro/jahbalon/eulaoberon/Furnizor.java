package ro.jahbalon.eulaoberon;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;

/**
 * Da fisierele din casa Eulei altor aplicatii, doar la cerere si doar de citit: instalatorul Android-ului primeste
 * asa APK-urile facute cu Aplicatie.Fa (de la Android 7 nu mai are voie sa le ia direct dupa cale).
 */
public class Furnizor extends ContentProvider {
    // v29: numele vine din pachetul aplicatiei (Eula poate sta si in alta aplicatie: apk X.Mod "Nume" eula)
    static String AUTORITATE = "ro.jahbalon.eulaoberon.fisiere";

    static Uri uri(File f) { return Uri.parse("content://" + AUTORITATE + "/home/" + Uri.encode(f.getName())); }

    @Override public boolean onCreate() { AUTORITATE = getContext().getPackageName() + ".fisiere"; return true; }

    File fisier(Uri u) throws FileNotFoundException {
        File home = new File(getContext().getFilesDir(), "home");
        String n = u.getLastPathSegment();
        if (n == null || n.contains("/") || n.startsWith(".")) throw new FileNotFoundException(String.valueOf(u));
        File f = new File(home, n);
        try {
            if (!f.getCanonicalPath().startsWith(home.getCanonicalPath() + File.separator)) throw new FileNotFoundException(f.getPath());
        } catch (IOException e) { throw new FileNotFoundException(e.toString()); }
        return f;
    }

    @Override public ParcelFileDescriptor openFile(Uri u, String mod) throws FileNotFoundException {
        return ParcelFileDescriptor.open(fisier(u), ParcelFileDescriptor.MODE_READ_ONLY);
    }

    @Override public String getType(Uri u) {
        String n = u.getLastPathSegment();
        return n != null && n.endsWith(".apk") ? "application/vnd.android.package-archive" : "application/octet-stream";
    }

    @Override public Cursor query(Uri u, String[] p, String s, String[] a, String o) {
        try {
            File f = fisier(u);
            android.database.MatrixCursor c = new android.database.MatrixCursor(new String[] {"_display_name", "_size"});
            c.addRow(new Object[] {f.getName(), f.length()});
            return c;
        } catch (FileNotFoundException e) { return null; }
    }
    @Override public Uri insert(Uri u, ContentValues v) { return null; }
    @Override public int delete(Uri u, String s, String[] a) { return 0; }
    @Override public int update(Uri u, ContentValues v, String s, String[] a) { return 0; }
}
