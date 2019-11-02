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
      opt << "--init-gpg PATH \t\tInitialize GPG in the directory.\n"
      opt << "--create-template \t\tCreates a template yml file to configure the MobileSecrets\n"
      opt << "--import SECRETS_PATH \tAdds MobileSecrets to GPG secrets\n"
      opt << "--export PATH \t\t\tCreates source file with obfuscated secrets at given PATH\n"
      opt << "--usage \t\t\tManual for using MobileSecrets.\n\n"
      opt << "Examples:\n"
      opt << "--import \"./MobileSecrets.yml\"\n"
      opt << "--export \"./Project/Src\"\n"
      opt << "--init-gpg \".\""
      opt
    end

    def usage
      usage = ""
      usage << "1) Create gpg first with --init-gpg \".\"\n"
      usage << "2) Create a template for MobileSecrets with --create-template\n"
      usage << "3) Configure MobileSecrets.yml with your hash key, secrets etc\n"
      usage << "4) Import edited template to encrypted secret.gpg with --import\n"
      usage << "5) Export secrets from secrets.gpg to source file with --export and PATH to project\n"
      usage << "6) Add exported source file to the project\n"
    end

    def perform_action command, argv_1, argv_2
      case command
      when "--create-template"
        FileUtils.cp("#{__dir__}/../lib/resources/example.yml", "#{Dir.pwd}#{File::SEPARATOR}MobileSecrets.yml")
      when "--export"
        return print_options if argv_1 == nil

        secrets_handler = MobileSecrets::SecretsHandler.new
        secrets_handler.export_secrets argv_1
      when "--init-gpg"
        return print_options if argv_1 == nil

        Dotgpg::Cli.new.init(argv_1)
      when "--import"
        return print_options if argv_1 == nil

        file = IO.read argv_1
        MobileSecrets::SecretsHandler.new.encrypt "./secrets.gpg", file, nil
      when "--encrypt-file"
        file = argv_1
        password = argv_2
        MobileSecrets::SecretsHandler.new.encrypt_file password, file, "#{file}.enc"
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
