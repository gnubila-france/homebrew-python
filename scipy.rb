class Scipy < Formula
  desc "Software for mathematics, science, and engineering"
  homepage "http://www.scipy.org"
  url "https://pypi.python.org/packages/source/s/scipy/scipy-0.17.0.tar.gz"
  sha256 "f600b755fb69437d0f70361f9e560ab4d304b1b66987ed5a28bdd9dd7793e089"
  head "https://github.com/scipy/scipy.git"

  bottle do
    sha256 "5ac4e055f2ab97c68b6bbcbcca4e7aca6845440cfc140a68b6b476f88a3a1532" => :el_capitan
    sha256 "d068254ccede0b4f9d76053e1a0350c56b42ed7f34ea7d81ec0595fb25411e90" => :yosemite
    sha256 "28689e03334309320f7045a02b1581a9ee4b105ce6205ee5923699cc2d504899" => :mavericks
  end

  option "without-python", "Build without python2 support"

  depends_on "swig" => :build
  depends_on :python => :recommended if MacOS.version <= :snow_leopard
  depends_on :python3 => :optional
  depends_on :fortran

  option "with-openblas", "Use openblas instead of Apple's Accelerate framework " \
                          "(required to build with gcc on OS X)"
  depends_on "gnubila-france/science/openblas" => (OS.mac? ? :optional : :recommended)

  numpy_options = []
  numpy_options << "with-python3" if build.with? "python3"
  numpy_options << "with-openblas" if build.with? "openblas"
  depends_on "gnubila-france/python/numpy" => numpy_options

  cxxstdlib_check :skip

  # https://github.com/Homebrew/homebrew-python/issues/110
  # There are ongoing problems with gcc+accelerate.
  fails_with :gcc if OS.mac? && build.without?("openblas")

  def install
    # https://github.com/numpy/numpy/issues/4203
    # https://github.com/Homebrew/homebrew-python/issues/209
    # https://github.com/Homebrew/homebrew-python/issues/233
    if OS.linux?
      ENV.append "FFLAGS", "-fPIC"
      ENV.append "LDFLAGS", "-shared"
    end

    config = <<-EOS.undent
      [DEFAULT]
      library_dirs = #{HOMEBREW_PREFIX}/lib
      include_dirs = #{HOMEBREW_PREFIX}/include
    EOS
    if build.with? "openblas"
      # For maintainers:
      # Check which BLAS/LAPACK numpy actually uses via:
      # xcrun otool -L $(brew --prefix)/Cellar/scipy/<version>/lib/python2.7/site-packages/scipy/linalg/_flinalg.so
      # or the other .so files.
      openblas_dir = Formula["openblas"].opt_prefix
      # Setting ATLAS to None is important to prevent numpy from always
      # linking against Accelerate.framework.
      ENV["ATLAS"] = "None"
      if OS.mac?
        openblas_lib_name = "libopenblas.dylib"
      else
        openblas_lib_name = "libopenblas.so"
      end
      ENV["BLAS"] = ENV["LAPACK"] = "#{openblas_dir}/lib/#{openblas_lib_name}"

      config << <<-EOS.undent
        [openblas]
        libraries = openblas
        library_dirs = #{openblas_dir}/lib
        include_dirs = #{openblas_dir}/include
      EOS
    end

    Pathname("site.cfg").write config

    # gfortran is gnu95
    Language::Python.each_python(build) do |python, version|
      ENV["PYTHONPATH"] = Formula["numpy"].opt_lib/"python#{version}/site-packages"
      ENV.prepend_create_path "PYTHONPATH", lib/"python#{version}/site-packages"
      system python, "setup.py", "build", "--fcompiler=gnu95"
      system python, *Language::Python.setup_install_args(prefix)
    end
  end

  # cleanup leftover .pyc files from previous installs which can cause problems
  # see https://github.com/Homebrew/homebrew-python/issues/185#issuecomment-67534979
  def post_install
    Language::Python.each_python(build) do |_python, version|
      rm_f Dir["#{HOMEBREW_PREFIX}/lib/python#{version}/site-packages/scipy/**/*.pyc"]
    end
  end

  def caveats
    if (build.with? "python") && !Formula["python"].installed?
      homebrew_site_packages = Language::Python.homebrew_site_packages
      user_site_packages = Language::Python.user_site_packages "python"
      <<-EOS.undent
        If you use system python (that comes - depending on the OS X version -
        with older versions of numpy, scipy and matplotlib), you may need to
        ensure that the brewed packages come earlier in Python's sys.path with:
          mkdir -p #{user_site_packages}
          echo 'import sys; sys.path.insert(1, "#{homebrew_site_packages}")' >> #{user_site_packages}/homebrew.pth
      EOS
    end
  end

  test do
    Language::Python.each_python(build) do |python, _version|
      system python, "-c", "import scipy; assert scipy.test().wasSuccessful()"
    end
  end
end
