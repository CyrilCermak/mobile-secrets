#!/usr/bin/env ruby
require_relative 'src/secrets_handler'
require "dotgpg"

module MobileSecrets
  class Cli

    def header
    "Mobile Secrets HELP:
    ##############################################################################################################################
    ##  %# #%%%( ##%  ,%%%  (%%/   *%%%% ,%%%/       .%%(  (%%,  #%%%#.(%%#   #%%*.#%%% ,%%%%%.%%%%.   #%%%%.#%%%.*%% %%%%*#%%  ##
    ##  %  #%%%(  % *%%%#  /%%%(  *%%%%  %%%%,      %%%*    %,  (%%%#   #( .%%%(    %%  (%%%#  %%%%    %%%%.  .%.*%  %%%%* #%   ##
    ##     #%%%(    %%%%#  /%%%%  *%%%%  %%%%.     .%%%%%%#.    (%%%( ,%   %%%%(    ,#  (%%%# .%%%%   .%%%%. (*  ,(  %%%%* .#   ##
    ##     #%%%(    %%%%#  /%%%%  /%%%% *%%%*       *%%%%%%%%   (%%%((%%   %%%%(        (%%%#.#%#,    .%%%%.%%*      %%%%,      ##
    ##     #%%%(    #%%%#  /%%%%  /%%%%            .(  (%%%%%#  (%%%( ,%   %%%%(        (%%%# *%%%#   .%%%%. #*      %%%%,      ##
    ##     %%%%(     %%%#  /%%%.  /%%%%            ,%,    %%%/  (%%%(   (# (%%%(    *#  #%%%# .%%%%   .%%%%    #,    %%%%,      ##
    ##    %%%%%%(     /%%**%%(   ,%%%%%(           ,%%#. /%%*   #%%%(./%%#  *%%#  .##   #%%%# .%%%%#/ .%%%%  ,%%,    %%%%,      ##
    ##############################################################################################################################"
    end

    def options
      opt = ""
      opt << "--init-gpg PATH \t\t\tInitialize GPG in the directory.\n"
      opt << "--create-template \t\t\tCreates a template yml file to configure the MobileSecrets\n"
      opt << "--import SECRETS_PATH \t\t\tAdds MobileSecrets to GPG secrets\n"
      opt << "--export PATH opt: ENCRYPTED_FILE_PATH \tCreates source file with obfuscated secrets at given PATH\n"
      opt << "--encrypt-file FILE PASSWORD \t\tEncrypt a single file with AES\n"
      opt << "--empty PATH \t\t\t\tGenerates a Secrets file without any data in it\n"
      opt << "--usage \t\t\t\tManual for using MobileSecrets.\n\n"
      opt << "Examples:\n"
      opt << "--import \"./MobileSecrets.yml\"\n"
      opt << "--export \"./Project/Src\\n"
      opt << "--init-gpg \".\""
      opt
    end

    def usage
      usage = ""
      usage << "1) Create gpg first with --init-gpg \".\"\n"
      usage << "2) Create a template for MobileSecrets with --create-template\n"
      usage << "3) Configure MobileSecrets.yml with your hash key, secrets etc\n"
      usage << "4) Import edited template to encrypted secret.gpg with --import ./MobileSecrets.yml\n"
      usage << "5) Export secrets from secrets.gpg to source file with --export and PATH to project\n"
      usage << "6) Add exported source file to the project\n"
    end

    def perform_action command, argv_1, argv_2
      case command
      when "--create-template"
        FileUtils.cp("#{__dir__}/../lib/resources/example.yml", "#{Dir.pwd}#{File::SEPARATOR}MobileSecrets.yml")
      when "--export"
        return print_options if argv_1 == nil
        encrypted_file_path = argv_2 ||= "secrets.gpg"

        secrets_handler = MobileSecrets::SecretsHandler.new
        secrets_handler.export_secrets argv_1, argv_2
      when "--init-gpg"
        return print_options if argv_1 == nil

        Dotgpg::Cli.new.init(argv_1)
      when "--import"
        return print_options if argv_1 == nil
        gpg_file = argv_2 ||= "secrets.gpg"
        file = IO.read argv_1
        MobileSecrets::SecretsHandler.new.encrypt gpg_file, file, nil
      when "--encrypt-file"
        file = argv_1
        password = argv_2
        MobileSecrets::SecretsHandler.new.encrypt_file password, file, "#{file}.enc"
      when "--empty"
        return print_options if argv_1 == nil
        file_path = argv_1
        
        MobileSecrets::SourceRenderer.new("swift").render_empty_template "#{file_path}/secrets.swift"
      when "--edit"
        return print_options if argv_1 == nil
        exec("dotgpg edit #{argv_1}")
      when "--usage"
        puts usage
      else
        print_options
      end
    end

    def print_options
      puts "#{header}\n\n#{options}" #Wrong action selected
    end

  end
end
