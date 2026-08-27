/*
 * Syntaxcheck für Cinnamon-Xlets.
 *
 * Cinnamon-JS lässt sich nicht einfach ausführen (die Typelibs Meta/Cinnamon
 * gibt es nur im Cinnamon-Prozess). new Function() parst die Datei, ohne sie
 * auszuführen – das prüft die Syntax und lässt die imports in Ruhe.
 *
 * Aufruf: cjs tools/syntaxcheck.js <datei> [<datei> ...]
 */

const GLib = imports.gi.GLib;
const ByteArray = imports.byteArray;
const System = imports.system;

let failed = 0;

for (const path of ARGV) {
    let src;
    try {
        const [ok, bytes] = GLib.file_get_contents(path);
        if (!ok) {
            throw new Error("Datei nicht lesbar");
        }
        src = ByteArray.toString(bytes);
    } catch (e) {
        printerr("FEHLER  " + path + ": " + e.message);
        failed++;
        continue;
    }

    try {
        new Function(src);
        print("OK      " + path);
    } catch (e) {
        printerr("FEHLER  " + path + ": " + e);
        failed++;
    }
}

System.exit(failed > 0 ? 1 : 0);
