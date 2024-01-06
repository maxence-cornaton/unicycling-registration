# Be sure to restart your server when you modify this file.
# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'
# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
# Rails.application.config.assets.precompile += %w( search.js )

Rails.application.config.assets.precompile += %w[
  wysiwyg.js
  pdf.css
  base_green_blue.css base_green_blue_split2.css
  base_blue_purple.css base_blue_purple_split2.css
  base_purple_blue.css base_purple_blue_split2.css
  base_blue_pink.css base_blue_pink_split2.css
  controllers/index.js
  controllers/entries_matching_controller.js
  controllers/pronouns_gender_controller.js
]
Rails.application.config.assets.precompile += %w[vendor/modernizr.js]
