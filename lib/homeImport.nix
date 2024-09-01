{lib, ...}:

with lib; 
{
  importFilesToHome = to: folder: builtins.listToAttrs 
    (map 
      (file: {
        name = "${to}/${folder}/${file}"; 
        value = { source = ./. + "/${folder}/${file}"; executable = true; };
      }) 
      (builtins.attrNames (builtins.readDir ./${folder}))
    );

  importFoldersToHome = to: folders: mkMerge (map (importFilesToHome to) folders);
}