#
# Be sure to run `pod lib lint BoredBoss.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "Boredboss-ios-sdk"
  s.version          = "0.1.0"
  s.summary          = "Boredboss SDK for iOS apps."
  s.description      = <<-DESC
                        Boredboss is a mobile analytics SAAS developed to measure app metrics.

                       * Light weight.
                       * 100% asynchronous.
                       * Track app events.
                       * Track user related properties.
                       * Automatic events out-of-the-box.
                       DESC
  s.homepage         = "https://github.com/meetsapp/boredboss-ios-sdk"
  s.license          = 'MIT'
  s.author           = { "Javier Berlana" => "jberlana@gmail.com" }
  s.source           = { :git => "https://github.com/meetsapp/boredboss-ios-sdk.git", :tag => "0.1.0" }
  s.social_media_url = 'https://twitter.com/meetsapp'

  s.platform     = :ios, '7.0'
  s.requires_arc = true
  s.source_files = 'Pod/Classes'
end
