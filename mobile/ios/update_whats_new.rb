require 'spaceship'

# The team ID is passed via environment variable FASTLANE_ITC_TEAM_ID
Spaceship::ConnectAPI.login("mattioli.simone.10@gmail.com")

app = Spaceship::ConnectAPI::App.find("com.simo.evolve")
version = app.get_edit_app_store_version

if version.nil?
  puts "Nessuna versione in stato editabile trovata!"
  exit 1
end

puts "Trovata versione: #{version.version_string}"

localizations = version.get_app_store_version_localizations

localizations.each do |loc|
  puts "Aggiornamento lingua: #{loc.locale}..."
  loc.update(whats_new: "UI improvements")
end

puts "Completato! Tutte le lingue sono state aggiornate con successo."
