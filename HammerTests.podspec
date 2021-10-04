Pod::Spec.new do |spec|
  spec.name          = "HammerTests"
  spec.version       = "0.13.2"
  spec.summary       = "iOS touch and keyboard syntheis library for unit tests."
  spec.description   = "Hammer is a touch and keyboard synthesis library for emulating user interaction events. It enables new ways of triggering UI actions in unit tests, replicating a real world environment as much as possible."
  spec.homepage      = "https://github.com/lyft/Hammer"
  spec.screenshots   = "https://user-images.githubusercontent.com/585835/116217617-ab410080-a6fe-11eb-9de1-3d42f7dd6037.gif"
  spec.license       = { :type => "Apache License, Version 2.0", :file => "./LICENSE" }
  spec.author        = { "Gabriel Lanata" => "gabriel@lanata.me" }
  spec.platform      = :ios, "11.0"
  spec.swift_version = "5.3"
  spec.frameworks    = 'XCTest'
  spec.source        = { :git => "https://github.com/lyft/Hammer.git", :tag => "#{spec.version}" }
  spec.source_files  = "Sources/**/*.swift"
  spec.requires_arc  = true
end
