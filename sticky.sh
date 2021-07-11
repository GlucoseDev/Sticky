if [ "$1" == "" ]; then
  echo "Specify MC version"
  exit
fi
tr(){
  wget https://maven.fabricmc.net/net/fabricmc/tiny-remapper/0.3.2/tiny-remapper-0.3.2-fat.jar
}
fernflower(){
  wget https://glucosedev.ml/resources/fernflower.jar
}
enigma(){
  wget https://maven.fabricmc.net/cuchaz/enigma-cli/1.4.1/enigma-cli-1.4.1-all.jar
}
downloadMc(){
  mcVersion="$1"
  downloadVersionManifest() {
    printf "Downloading main version_manifest.json..."
    curl --create-dirs -s -o .cache/version_manifest.json "https://launchermeta.mojang.com/mc/game/version_manifest.json" || exit 1
    printf " Done!\n"
}

downloadTargettedVersion() {
    printf "Downloading $mcVersion version_manifest.json..."
    versionSpecificManifest=$(grep -o "https:\/\/launchermeta\.mojang\.com\/v1\/packages\/.\{40\}\/$mcVersion.json" .cache/version_manifest.json)
    curl --create-dirs -s -o ".cache/$mcVersion/version_manifest.json" "$versionSpecificManifest" || exit 1
    printf " Done!\n"

    printf "Downloading $mcVersion Minecraft server jar and mappings..."
    versionSpecificServerUri=$(grep -o "https:\/\/launcher\.mojang\.com\/v1\/objects\/.\{40\}\/server\.jar" .cache/$mcVersion/version_manifest.json)
    versionSpecificMappingsUri=$(grep -o "https:\/\/launcher\.mojang\.com\/v1\/objects\/.\{40\}\/server\.txt" .cache/$mcVersion/version_manifest.json)

    curl --create-dirs -s -o ".cache/$mcVersion/server.jar" "$versionSpecificServerUri" || exit 1
    curl --create-dirs -s -o ".cache/$mcVersion/server.txt" "$versionSpecificMappingsUri" || exit 1
    printf " Done!\n"
}

downloadVersionManifest
downloadTargettedVersion
}
decompile(){
  mapServerJar() {
    printf "Converting $mcVersion Minecraft mappings..."
    java -cp "enigma-cli-1.4.1-all.jar" "cuchaz.enigma.command.Main" convert-mappings proguard ".cache/$mcVersion/server.txt" tinyv2:obf:deobf ".cache/$mcVersion/server.tiny" || exit 1
    printf " Done!\n"

    printf "Mapping $mcVersion Minecraft server jar...\n"
    java -jar "tiny-remapper-0.3.2-fat.jar" ".cache/$mcVersion/server.jar" ".cache/$mcVersion/server-deobf.jar" ".cache/$mcVersion/server.tiny" obf deobf --renameInvalidLocals || exit 1

    #printf "Installing $mcVersion mapped Minecraft server jar in your local maven repo..."
    #mvn install:install-file -Dfile=".cache/$mcVersion/server-deobf.jar" -DgroupId="ml.glucosedev" -DartifactId="minecraft-server" -Dversion="$mcVersion-SNAPSHOT" -Dpackaging="jar" > /dev/null
    printf " Done!\n"
}

decom() {
    printf "Extracting $mcVersion mapped Minecraft server jar..."
    unzip -o ".cache/$mcVersion/server-deobf.jar" "net/**/*" -d ".cache/$mcVersion/extracted/" > /dev/null
    printf " Done!\n"

    printf "Decompiling $mcVersion mapped Minecraft source...\n"
    mkdir -p ".cache/$mcVersion/decompiled/"
    java -jar "./fernflower.jar" -dgs=1 -hdc=0 -rbr=0 -asc=1 -udv=0 ".cache/$mcVersion/extracted/" ".cache/$mcVersion/decompiled/"
    #cp -r .cache/$mcVersion/decompiled/net src/main/java/
    printf "Done!\n"
}

mapServerJar
decom
}

mkdir -p .cache/$mcVersion/decompiled
downloadMc "$1"
tr
fernflower
enigma
decompile
# Glucose
mkdir libs/
echo "Copying deobfuscated jar into libs directory"
cp .cache/$mcVersion/server-deobf.jar libs/server-deobf.jar
