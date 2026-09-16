#!/usr/bin/env bash
# macOS system preferences. Applied by hand rather than stowed, because macOS
# keeps these in a preferences database instead of files that can be symlinked.
#
# Idempotent; re-run after an OS upgrade. Log out and back in to apply fully.

set -euo pipefail

# Close System Settings so it cannot overwrite what is written below.
osascript -e 'tell application "System Settings" to quit' || true

# Keyboard
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Trackpad
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 1
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true

# Mouse
defaults write NSGlobalDomain com.apple.mouse.linear -bool true
defaults write NSGlobalDomain com.apple.mouse.scaling -float 0.5

# Scrolling
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# Finder
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string 'Nlsv'
defaults write com.apple.finder FXDefaultSearchScope -string 'SCcf'
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# .DS_Store
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock tilesize -int 42
defaults write com.apple.dock mru-spaces -bool false
defaults write com.apple.dock persistent-others -array

# Screenshots
mkdir -p "${HOME}/Pictures/Screenshots"
defaults write com.apple.screencapture location -string "${HOME}/Pictures/Screenshots"
defaults write com.apple.screencapture type -string 'png'
defaults write com.apple.screencapture disable-shadow -bool true

# Misc
defaults write NSGlobalDomain AppleInterfaceStyle -string 'Dark'
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

killall Dock Finder SystemUIServer 2>/dev/null || true

echo 'Done. Log out and back in for everything to take effect.'
