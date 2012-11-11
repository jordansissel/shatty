Gem::Specification.new do |spec|
  files = %x{git ls-files}.split("\n")

  spec.name = "shatty"
  spec.version = "0.0.8"
  spec.summary = "shatty"
  spec.description = "shatty"
  spec.license = "none chosen yet"

  # Note: You should set the version explicitly.
  spec.add_dependency "cabin", ">0" # for logging. apache 2 license
  spec.add_dependency "clamp", ">0"
  spec.add_dependency "ftw", ">0"
  spec.add_dependency "uuidtools", ">0"
  spec.files = files
  spec.require_paths << "lib"
  spec.bindir = "bin"
  spec.executables << "shatty"

  spec.authors = ["Jordan Sissel"]
  spec.email = ["jls@semicomplete.com"]
  #spec.homepage = "..."
end

