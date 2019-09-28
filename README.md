# mobile-secrets
Mobile Secrets HELP:
    ##############################################################################################################################
    ##  %# #%%%( ##%  ,%%%  (%%/   *%%%% ,%%%/       .%%(  (%%,  #%%%#.(%%#   #%%*.#%%% ,%%%%%.%%%%.   #%%%%.#%%%.*%% %%%%*#%%  ##
    ##  %  #%%%(  % *%%%#  /%%%(  *%%%%  %%%%,      %%%*    %,  (%%%#   #( .%%%(    %%  (%%%#  %%%%    %%%%.  .%.*%  %%%%* #%   ##
    ##     #%%%(    %%%%#  /%%%%  *%%%%  %%%%.     .%%%%%%#.    (%%%( ,%   %%%%(    ,#  (%%%# .%%%%   .%%%%. (*  ,(  %%%%* .#   ##
    ##     #%%%(    %%%%#  /%%%%  /%%%% *%%%*       *%%%%%%%%   (%%%((%%   %%%%(        (%%%#.#%#,    .%%%%.%%*      %%%%,      ##
    ##     #%%%(    #%%%#  /%%%%  /%%%%            .(  (%%%%%#  (%%%( ,%   %%%%(        (%%%# *%%%#   .%%%%. #*      %%%%,      ##
    ##     %%%%(     %%%#  /%%%.  /%%%%            ,%,    %%%/  (%%%(   (# (%%%(    *#  #%%%# .%%%%   .%%%%    #,    %%%%,      ##
    ##    %%%%%%(     /%%**%%(   ,%%%%%(           ,%%#. /%%*   #%%%(./%%#  *%%#  .##   #%%%# .%%%%#/ .%%%%  ,%%,    %%%%,      ##
    ##############################################################################################################################

--init-gpg PATH 		Initialize GPG in the directory.
--create-template 		Creates a template yml file to configure the MobileSecrets
--import SECRETS_PATH 	Adds MobileSecrets to GPG secrets
--export PATH 			Creates source file with obfuscated secrets at given PATH
--usage 			Manual for using MobileSecrets.

Examples:
--import "./MobileSecrets.yml"
--export "./Project/Src"
--init-gpg "."

Usage:
1) Create gpg first with --init-gpg "."
2) Create a template for MobileSecrets with --create-template
3) Configure MobileSecrets.yml with your hash key, secrets etc
4) Import edited template to encrypted secret.gpg with --import
5) Export secrets from secrets.gpg to source file with --export and PATH to project
6) Add exported source file to the project
