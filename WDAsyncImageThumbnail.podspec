Pod::Spec.new do |s|
  s.name             = "WDAsyncImageThumbnail"
  s.version          = "0.1.0"
  s.summary          = "Load an image or video thumbnail in background on OSX."
  s.description      = <<-DESC
This small library loads a thumbnail of a file (photo or video) in a
background thread and calls u back on the main thread. Features caching usning NSCache
class what is nice when loading thumbnails from remote filesystems.
                       DESC

  s.homepage         = "https://github.com/fredmajor/WDAsyncImageThumbnail"
  s.license          = 'MIT'
  s.author           = { "Fred" => "major.freddy@yahoo.com" }
  s.source           = { :git => "https://github.com/fredmajor/WDAsyncImageThumbnail.git", :tag => s.version.to_s }
  s.platform     = :osx, '10.9'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'WDAsyncImageThumbnail' => ['Pod/Assets/*.png']
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
