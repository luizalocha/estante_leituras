"""Ajusta os arquivos Android gerados pelo `flutter create`.

Executar UMA vez, a partir da pasta do projeto, depois do `flutter create`:

    python tools/configurar_android.py

O script é idempotente (pode rodar de novo sem duplicar nada). Ele:
  1. adiciona INTERNET e CAMERA ao AndroidManifest principal
     (sem INTERNET o APK de release não acessa Firebase nem a Open Library);
  2. troca o nome exibido do app para "Estante";
  3. permite HTTP local só no build de debug (Firebase Emulator em 10.0.2.2);
  4. garante minSdk >= 23 (exigência do Firebase);
  5. configura a assinatura de release lendo android/key.properties.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ANDROID = ROOT / "android"
APP = ANDROID / "app"


def fail(msg: str) -> None:
    print("ERRO:", msg)
    sys.exit(1)


def patch_manifest() -> None:
    path = APP / "src" / "main" / "AndroidManifest.xml"
    if not path.exists():
        fail(f"{path} não existe. Rode `flutter create` antes.")
    xml = path.read_text(encoding="utf-8")

    perms = [
        '<uses-permission android:name="android.permission.INTERNET"/>',
        '<uses-permission android:name="android.permission.CAMERA"/>',
        '<uses-feature android:name="android.hardware.camera" android:required="false"/>',
    ]
    missing = [p for p in perms if p.split('"')[1] not in xml]
    if missing:
        block = "\n    ".join(missing)
        xml = re.sub(r"(<manifest[^>]*>)", r"\1\n    " + block, xml, count=1)

    xml = re.sub(r'android:label="[^"]*"', 'android:label="Estante"', xml, count=1)
    path.write_text(xml, encoding="utf-8")
    print("ok  AndroidManifest.xml (INTERNET, CAMERA, nome do app)")


def patch_debug_manifest() -> None:
    path = APP / "src" / "debug" / "AndroidManifest.xml"
    if not path.exists():
        return
    xml = path.read_text(encoding="utf-8")
    if "usesCleartextTraffic" in xml:
        print("ok  debug/AndroidManifest.xml (já ajustado)")
        return
    if "<application" in xml:
        xml = xml.replace("<application", '<application android:usesCleartextTraffic="true"', 1)
    else:
        xml = xml.replace(
            "</manifest>",
            '    <application android:usesCleartextTraffic="true"/>\n</manifest>',
            1,
        )
    path.write_text(xml, encoding="utf-8")
    print("ok  debug/AndroidManifest.xml (HTTP local só em debug, para o emulador do Firebase)")


IMPORTS = '''import java.io.FileInputStream
import java.util.Properties

'''

SIGNING_HEADER = '''// Assinatura de release: lida de android/key.properties (fora do Git).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

'''

SIGNING_CONFIGS = '''
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
'''


def patch_gradle_kts(path: pathlib.Path) -> None:
    gradle = path.read_text(encoding="utf-8")

    if "keystoreProperties" not in gradle:
        # Cabeçalho depois do bloco plugins { ... }
        m = re.search(r"plugins\s*\{[^}]*\}\s*", gradle)
        if not m:
            fail("bloco plugins { } não encontrado em build.gradle.kts")
        gradle = gradle[: m.end()] + "\n" + SIGNING_HEADER + gradle[m.end():]
        # Em Kotlin DSL os imports precisam ficar no topo do arquivo.
        gradle = IMPORTS + gradle

        # signingConfigs antes de buildTypes
        gradle = gradle.replace("    buildTypes {", SIGNING_CONFIGS + "\n    buildTypes {", 1)

        # release passa a usar a assinatura própria
        gradle = re.sub(
            r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
            'signingConfig = signingConfigs.getByName("release")',
            gradle,
        )

    gradle = re.sub(
        r"minSdk\s*=\s*flutter\.minSdkVersion",
        "minSdk = maxOf(23, flutter.minSdkVersion)",
        gradle,
    )
    path.write_text(gradle, encoding="utf-8")
    print("ok  app/build.gradle.kts (minSdk >= 23, assinatura de release)")


def main() -> None:
    patch_manifest()
    patch_debug_manifest()
    kts = APP / "build.gradle.kts"
    groovy = APP / "build.gradle"
    if kts.exists():
        patch_gradle_kts(kts)
    elif groovy.exists():
        fail("Projeto com build.gradle (Groovy). Me avise que eu ajusto manualmente.")
    else:
        fail("build.gradle.kts não encontrado. Rode `flutter create` antes.")
    print("\nPronto. Confira com: git diff android/")


if __name__ == "__main__":
    main()
