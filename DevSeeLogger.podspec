Pod::Spec.new do |s|
  s.name             = "DevSeeLogger"
  s.version          = "0.1.0"
  s.summary          = "Minimal Swift logger that sends API logs to a dev-see server."
  s.description      = <<-DESC
DevSeeLogger is a lightweight Swift logging library for manually sending
request/response activity to a dev-see log server.
  DESC

  # Update these values before publishing this pod to CocoaPods trunk.
  s.homepage         = "https://github.com/your-username/dev-see"
  s.license          = { :type => "UNLICENSED", :text => "License not yet specified." }
  s.author           = { "dev-see" => "maintainers@dev-see.local" }
  s.source           = { :git => "https://github.com/your-username/dev-see.git", :tag => s.version.to_s }

  s.swift_versions   = ["5.9", "6.0"]
  s.ios.deployment_target = "15.0"
  s.osx.deployment_target = "12.0"
  s.tvos.deployment_target = "15.0"
  s.watchos.deployment_target = "8.0"

  # Support both local package directory usage and repo-root source checkout usage.
  s.source_files = [
    "Sources/DevSeeLogger/**/*.swift",
    "packages/swift/dev-see-logger/Sources/DevSeeLogger/**/*.swift"
  ]
end
