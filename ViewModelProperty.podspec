Pod::Spec.new do |s|
  s.name         = "ViewModelProperty"
  s.version      = "0.1"
  s.summary      = "View Model Property"
  s.description  = <<-DESC
                   Provides infomation when updating an property
                   DESC
  s.homepage     = "https://github.com/CosynPa/ViewModelProperty"
  s.license      = "MIT"
  s.author       = "CosynPa"

  s.ios.deployment_target = "8.0"

  s.source       = { :git => "https://github.com/CosynPa/ViewModelProperty.git", :tag => "0.1" }
  s.source_files = "ViewModelProperty/*.{swift,h,m}"

  s.dependency 'ReactiveSwift', '~> 1.0'
end
