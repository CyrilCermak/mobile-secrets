# Mobile secrets
Mobile Secrets<br/>
*Handle mobile secrets the secure way with ease*

HELP:
--init-gpg PATH 		Initialize GPG in the directory.<br/>
--create-template 		Creates a template yml file to configure the MobileSecrets<br/>
--import SECRETS_PATH 	Adds MobileSecrets to GPG secrets<br/>
--export PATH 			Creates source file with obfuscated secrets at given PATH<br/>
--usage 			Manual for using MobileSecrets.<br/>

Examples:<br/>
--import "./MobileSecrets.yml"<br/>
--export "./Project/Src"<br/>
--init-gpg "."<br/>

Usage:<br/>
1) Create gpg first with --init-gpg "."<br/>
2) Create a template for MobileSecrets with --create-template<br/>
3) Configure MobileSecrets.yml with your hash key, secrets etc<br/>
4) Import edited template to encrypted secret.gpg with --import<br/>
5) Export secrets from secrets.gpg to source file with --export and PATH to project<br/>
6) Add exported source file to the project<br/>
