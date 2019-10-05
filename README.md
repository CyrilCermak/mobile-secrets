# Mobile secrets
*Handle mobile secrets the secure way with ease*

Working with this plugin is described in detail here: https://medium.com/@cyrilcermak/mobile-secrets-8458ceaf4c16

Usage:<br/>
1) Create gpg first with --init-gpg "."<br/>
2) Create a template for MobileSecrets with --create-template<br/>
3) Configure MobileSecrets.yml with your hash key, secrets etc<br/>
4) Import edited template to encrypted secret.gpg with --import<br/>
5) Export secrets from secrets.gpg to source file with --export and PATH to project<br/>
6) Add exported source file to the project<br/>
