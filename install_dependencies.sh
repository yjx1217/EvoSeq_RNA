#!/bin/bash
set -e -o pipefail
# last update: 2024/04/26

#########################
EVOSEQ_HOME=$(pwd)
BUILD="build"
mainland_china_installation="no";
#########################

timestamp () {
  date +"%F %T"
}

clean () {
    dir=$1
    if [ -d $dir ] 
    then
	echo "remove previously failed installation in $BUILD/$dir"
	rm -rf $dir
    fi
}

clone () {
  url=$1
  dir=$(basename $url)
  echo "run clone for \"git clone $url\""
  git clone $url --depth 1
  cd $dir
  git fetch --unshallow
}

download () {
  url=$1
  download_location=$2
  echo "Downloading $url to $download_location"
  wget -c --no-check-certificate $url -O $download_location
}

tidy_version () { 
    echo "$1" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }';
}

check_installed () {
    if [ -e "$1/installed" ]; then
        echo "installed"
    else
        echo ""
    fi
}

note_installed () {
    touch "$1/installed"
}

echo ""
echo ""
echo "##################################################################"
echo "###                                                            ###"
echo "###                  Welcome to EvoSeq                         ###"
echo "###                                                            ###"
echo "##################################################################"
echo ""
echo ""
echo "[$(timestamp)] Installation starts ..."
echo ""

if [ -z "$MAKE_JOBS" ]
then
    echo "[$(timestamp)] Defaulting to 2 concurrent jobs when executing make. Override with MAKE_JOBS=<NUM>"
    MAKE_JOBS=2
    echo ""
fi

while getopts ":hc" opt
do
    case "${opt}" in
        h)
            echo "Usage:"
            echo "bash install_dependencies.sh"
            echo "When installing within mainland China, please run this script with the '-c' option >"
            echo "bash install_dependencies.sh -c";;
        c)
            echo "Detected the '-c' option >"
            echo "Set installation location as 'mainland_china'" 
            mainland_china_installation="yes";;
    esac
done

MINICONDA3_VERSION="py311_24.3.0-0" # released on 2024.04.15
if [[ "$mainland_china_installation" == "no" ]]
then
    MINICONDA3_DOWNLOAD_URL="https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA3_VERSION}-Linux-x86_64.sh"
else
    MINICONDA3_DOWNLOAD_URL="https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-${MINICONDA3_VERSION}-Linux-x86_64.sh"
fi

BEDTOOLS_VERSION="2.29.0" # released on 2017.12.14
BEDTOOLS_DOWNLOAD_URL="https://github.com/arq5x/bedtools2/releases/download/v${BEDTOOLS_VERSION}/bedtools-${BEDTOOLS_VERSION}.tar.gz"

FASTQC_VERSION="0.12.1" # released on 2023.03.01
# FASTQC_DOWNLOAD_URL="https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v${FASTQC_VERSION}.zip"

MULTIQC_VERSION="1.21" # released on 2024.02.28

GFFREAD_VERSION="0.12.2"
GFFREAD_DOWNLOAD_URL="https://ccb.jhu.edu/software/stringtie/dl/gffread-${GFFREAD_VERSION}.Linux_x86_64.tar.gz"

SAMTOOLS_VERSION="1.20" # released on 2024.04.15
HTSLIB_VERSION="1.20" # released on 2024.04.15
SAMTOOLS_DOWNLOAD_URL="https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2"

MASHMAP_VERSION="2.0"
MASHMAP_DOWNLOAD_URL="https://github.com/marbl/MashMap/releases/download/v${MASHMAP_VERSION}/mashmap-Linux64-v${MASHMAP_VERSION}.tar.gz"

SALMON_VERSION="1.10.0" # released on 2023.02.24
SALMON_DOWNLOAD_URL="https://github.com/COMBINE-lab/salmon/releases/download/v${SALMON_VERSION}/salmon-${SALMON_VERSION}_linux_x86_64.tar.gz"

TRIMMOMATIC_VERSION="0.38" # released on 
TRIMMOMATIC_DOWNLOAD_URL="http://www.usadellab.org/cms/uploads/supplementary/Trimmomatic/Trimmomatic-${TRIMMOMATIC_VERSION}.zip"

PICARD_VERSION="2.19.0" # released on 2019.03.22 
PICARD_DOWNLOAD_URL="https://github.com/broadinstitute/picard/releases/download/${PICARD_VERSION}/picard.jar"

PARALLEL_VERSION="20180722" # released on 2018.07.22
PARALLEL_DOWNLOAD_URL="http://ftp.gnu.org/gnu/parallel/parallel-${PARALLEL_VERSION}.tar.bz2"


if [ -d $BUILD ]
then
    echo ""
    echo "[$(timestamp)] Detected previously generated $BUILD directory."
else
    echo "[$(timestamp)] Create the new $BUILD directory."
    mkdir $BUILD
    echo ""
fi

cd $BUILD
build_dir=$(pwd)

# Downloading all the dependencies
echo ""
echo "[$(timestamp)] Download and install all the dependencies ..."

# ---------- set Perl & R environment variables -------------
#PYTHONPATH="$build_dir"
PERL5LIB="$build_dir:$PERL5LIB"
PERL5LIB="$build_dir/cpanm/perlmods/lib/perl5:$PERL5LIB"
R_LIBS="$build_dir/R_libs:$R_LIBS"
echo ""
echo "[$(timestamp)] Installing Perl modules ..."
cpanm_dir="$build_dir/cpanm"
if [ -z $(check_installed $cpanm_dir) ]; then
    clean $cpanm_dir
    mkdir -p $cpanm_dir
    cd $cpanm_dir
    #wget -c --no-check-certificate -O - https://cpanmin.us/ > cpanm
    cp $EVOSEQ_HOME/misc/cpanm .

    chmod +x cpanm
    mkdir perlmods

    $cpanm_dir/cpanm -l $cpanm_dir/perlmods --skip-installed Test::More@1.302086
    $cpanm_dir/cpanm -l $cpanm_dir/perlmods --skip-installed Text::Soundex@3.05
    $cpanm_dir/cpanm -l $cpanm_dir/perlmods --skip-installed Env@1.04
    # $cpanm_dir/cpanm -l $cpanm_dir/perlmods --skip-installed Statistics::Descriptive@3.0612
    # $cpanm_dir/cpanm -l $cpanm_dir/perlmods --skip-installed Statistics::Descriptive::Discrete@0.07
    # $cpanm_dir/cpanm -l $cpanm_dir/perlmods --skip-installed Math::Random@0.72
    # $cpanm_dir/cpanm -l $cpanm_dir/perlmods --skip-installed Math::Round@0.07
    # $cpanm_dir/cpanm -l $cpanm_dir/perlmods --skip-installed Sys::Syslog@0.35

    note_installed $cpanm_dir
fi    

echo ""
echo "[$(timestamp)] Installing R libraries ..."
rlib_dir="$build_dir/R_libs"
mkdir -p $rlib_dir
cd $rlib_dir
R_VERSION=$(R --version |head -1 |cut -d " " -f 3)

if [ -z $(check_installed "$rlib_dir/stringi") ]; then
    clean "$rlib_dir/stringi"
    R -e "install.packages(\"stringi\", repos=\"http://cran.rstudio.com/\", lib=\"$build_dir/R_libs/\", configure.vars=\"ICUDT_DIR=$build_dir/../misc/\")"
    note_installed "$rlib_dir/stringi"
fi

if [ -z $(check_installed "$rlib_dir/optparse") ]; then
    clean "$rlib_dir/optparse"
    R -e "install.packages(\"optparse\", repos=\"http://cran.rstudio.com/\", lib=\"$build_dir/R_libs/\")"
    note_installed "$rlib_dir/optparse"
fi

if [ -z $(check_installed "$rlib_dir/RColorBrewer") ]; then
    clean "$rlib_dir/RColorBrewer"
    R -e "install.packages(\"RColorBrewer\", repos=\"http://cran.rstudio.com/\", lib=\"$build_dir/R_libs/\")"
    note_installed "$rlib_dir/RColorBrewer"
fi

if [ -z $(check_installed "$rlib_dir/ggplot2") ]; then
    clean "$rlib_dir/ggplot2"
    R -e "install.packages(\"ggplot2\", repos=\"http://cran.rstudio.com/\", lib=\"$build_dir/R_libs/\")"
    note_installed "$rlib_dir/ggplot2"
fi

if [ -z $(check_installed "$rlib_dir/ggrepel") ]; then
    clean "$rlib_dir/repel"
    R -e "install.packages(\"ggrepel\", repos=\"http://cran.rstudio.com/\", lib=\"$build_dir/R_libs/\")"
    note_installed "$rlib_dir/ggrepel"
fi

if [ -z $(check_installed "$rlib_dir/gplots") ]; then
    clean "$rlib_dir/gplots"
    R -e "install.packages(\"gplots\", repos=\"http://cran.rstudio.com/\", lib=\"$build_dir/R_libs/\")"
    note_installed "$rlib_dir/gplots"
fi

if [ -z $(check_installed "$rlib_dir/corrplot") ]; then
    clean "$rlib_dir/corrplot"
    R -e "install.packages(\"corrplot\", repos=\"http://cran.rstudio.com/\", lib=\"$build_dir/R_libs/\")"
    note_installed "$rlib_dir/corrplot"
fi

if [ -z $(check_installed "$rlib_dir/pheatmap") ]; then
    clean "$rlib_dir/pheatmap"
    R -e "install.packages(\"pheatmap\", repos=\"http://cran.rstudio.com/\", lib=\"$build_dir/R_libs/\")"
    note_installed "$rlib_dir/pheatmap"
fi

if [ -z $(check_installed "$rlib_dir/reshape2") ]; then
    clean "$rlib_dir/reshape2"
    R -e "install.packages(\"reshape2\", repos=\"http://cran.rstudio.com/\", lib=\"$build_dir/R_libs/\")"
    note_installed "$rlib_dir/reshape2"
fi

if [ -z $(check_installed "$rlib_dir/scales") ]; then
    clean "$rlib_dir/scales"
    R -e "install.packages(\"scales\", repos=\"http://cran.rstudio.com/\", lib=\"$build_dir/R_libs/\")"
    note_installed "$rlib_dir/scales"
fi

if [ -z $(check_installed "$rlib_dir/viridis") ]; then
    clean "$rlib_dir/viridis"
    R -e "install.packages(\"viridis\", repos=\"http://cran.rstudio.com/\", lib=\"$build_dir/R_libs/\")"
    note_installed "$rlib_dir/viridis"
fi

if [ $(tidy_version "$R_VERSION") -ge $(tidy_version "3.6.0") ]; then
    if [ -z $(check_installed "$rlib_dir/BiocManager") ]; then
	clean "$rlib_dir/BiocManager"
	echo "R_VERSION=$R_VERSION, use the new bioconductor installation protocol"
	R -e ".libPaths(\"$build_dir/R_libs/\");install.packages(\"BiocManager\", repos=\"http://cran.rstudio.com/\", lib=\"$build_dir/R_libs/\")";
	note_installed "$rlib_dir/BiocManager"
    fi
else
    die "R >= v3.6.0 is needed! Exit!"
fi

if [ -z $(check_installed "$rlib_dir/BH") ]; then
    clean "$rlib_dir/BH"
    R -e ".libPaths(\"$build_dir/R_libs/\");BiocManager::install(\"BH\")"
    note_installed "$rlib_dir/BH"
fi

if [ -z $(check_installed "$rlib_dir/BiocParallel") ]; then
    clean "$rlib_dir/BiocParallel"
    R -e ".libPaths(\"$build_dir/R_libs/\");BiocManager::install(\"BiocParallel\")"
    R -e "sessionInfo()"
    note_installed "$rlib_dir/BiocParallel"
fi

if [ -z $(check_installed "$rlib_dir/tximport") ]; then
    clean "$rlib_dir/tximport"
    R -e ".libPaths(\"$build_dir/R_libs/\");BiocManager::install(\"tximport\")"
    note_installed "$rlib_dir/tximport"
fi

if [ -z $(check_installed "$rlib_dir/SummarizedExperiment") ]; then
    clean "$rlib_dir/SummarizedExperiment"
    R -e ".libPaths(\"$build_dir/R_libs/\");BiocManager::install(\"SummarizedExperiment\")"
    note_installed "$rlib_dir/SummarizedExperiment"
fi

if [ -z $(check_installed "$rlib_dir/DESeq2") ]; then
    clean "$rlib_dir/DESeq2"
    R -e ".libPaths(\"$build_dir/R_libs/\");BiocManager::install(\"DESeq2\")"
    note_installed "$rlib_dir/DESeq2"
fi

if [ -z $(check_installed "$rlib_dir/RUVSeq") ]; then
    clean "$rlib_dir/RUVSeq"
    R -e ".libPaths(\"$build_dir/R_libs/\");BiocManager::install(\"RUVSeq\")"
    note_installed "$rlib_dir/RUVSeq"
fi

# if [ -z $(check_installed "$rlib_dir/clusterProfiler") ]; then
#     clean "$rlib_dir/clusterProfiler"
#     R -e ".libPaths(\"$build_dir/R_libs/\");BiocManager::install(\"clusterProfiler\")"
#     note_installed "$rlib_dir/clusterProfiler"
# fi

# if [ -z $(check_installed "$rlib_dir/Homo.sapiens") ]; then
#     clean "$rlib_dir/Homo.sapiens"
#     R -e ".libPaths(\"$build_dir/R_libs/\");BiocManager::install(\"Homo.sapiens\")"
#     note_installed "$rlib_dir/Homo.sapiens"
# fi

# if [ -z $(check_installed "$rlib_dir/Mus.musculus") ]; then
#     clean "$rlib_dir/Mus.musculus"
#     R -e ".libPaths(\"$build_dir/R_libs/\");BiocManager::install(\"Mus.musculus\")"
#     note_installed "$rlib_dir/Mus.musculus"
# fi



# install dependencies

# ------------- Miniconda3 --------------------
echo ""
echo "[$(timestamp)] Installing miniconda3 ..."
miniconda3_dir="$build_dir/miniconda3/bin"
if [ -z $(check_installed $miniconda3_dir) ]; then
    cd $build_dir
    clean "$build_dir/miniconda3"
    download $MINICONDA3_DOWNLOAD_URL "Miniconda3-${MINICONDA3_VERSION}-Linux-x86_64.sh"
    bash Miniconda3-${MINICONDA3_VERSION}-Linux-x86_64.sh -b -p $build_dir/miniconda3
    if [[ "$mainland_china_installation" == "yes" ]]
    then

        $miniconda3_dir/conda config --add channels https://mirrors.bfsu.edu.cn/anaconda/pkgs/main
        $miniconda3_dir/conda config --add channels https://mirrors.bfsu.edu.cn/anaconda/pkgs/free
        $miniconda3_dir/conda config --add channels https://mirrors.bfsu.edu.cn/anaconda/pkgs/pro
        $miniconda3_dir/conda config --add channels https://mirrors.bfsu.edu.cn/anaconda/pkgs/msys2
        $miniconda3_dir/conda config --add channels https://mirrors.bfsu.edu.cn/anaconda/cloud/bioconda
        $miniconda3_dir/conda config --add channels https://mirrors.bfsu.edu.cn/anaconda/cloud/conda-forge

        $miniconda3_dir/conda config --add channels https://anaconda.mirrors.sjtug.sjtu.edu.cn/pkgs/main
        $miniconda3_dir/conda config --add channels https://anaconda.mirrors.sjtug.sjtu.edu.cn/pkgs/free
        $miniconda3_dir/conda config --add channels https://anaconda.mirrors.sjtug.sjtu.edu.cn/pkgs/pro
        $miniconda3_dir/conda config --add channels https://anaconda.mirrors.sjtug.sjtu.edu.cn/pkgs/msys2
        $miniconda3_dir/conda config --add channels https://anaconda.mirrors.sjtug.sjtu.edu.cn/cloud/bioconda
        $miniconda3_dir/conda config --add channels https://anaconda.mirrors.sjtug.sjtu.edu.cn/cloud/conda-forge

        # $miniconda3_dir/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/
        # $miniconda3_dir/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/
        # $miniconda3_dir/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/pytorch/
        # $miniconda3_dir/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/bioconda/
        # $miniconda3_dir/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge/
    else 
        $miniconda3_dir/conda config --add channels defaults
        $miniconda3_dir/conda config --add channels bioconda
        $miniconda3_dir/conda config --add channels conda-forge
    fi
    $miniconda3_dir/conda config --set channel_priority strict
    $miniconda3_dir/conda config --set show_channel_urls yes
    cd $build_dir
    rm Miniconda3-${MINICONDA3_VERSION}-Linux-x86_64.sh 
    note_installed $miniconda3_dir
fi

# --------------- fastQC --------------------
echo ""
echo "[$(timestamp)] Installing FastQC ..."
fastqc_dir="$build_dir/fastqc_conda_env/bin"
if [ -z $(check_installed $fastqc_dir) ]; then
    cd $build_dir
    $miniconda3_dir/conda create -y -p $build_dir/fastqc_conda_env python=3.11
    source $miniconda3_dir/activate $build_dir/fastqc_conda_env
    $miniconda3_dir/conda install -y -c bioconda fastqc=${FASTQC_VERSION}
    source $miniconda3_dir/deactivate
    note_installed $fastqc_dir
fi

# --------------- multiQC --------------------
echo ""
echo "[$(timestamp)] Installing Multiqc ..."
multiqc_dir="$build_dir/multiqc_conda_env/bin"
if [ -z $(check_installed $multiqc_dir) ]; then
    cd $build_dir
    $miniconda3_dir/conda create -y -p $build_dir/multiqc_conda_env python=3.11
    source $miniconda3_dir/activate $build_dir/multiqc_conda_env
    $miniconda3_dir/conda install -y -c bioconda multiqc=${MULTIQC_VERSION}
    source $miniconda3_dir/deactivate
    note_installed $multiqc_dir
fi

# --------------- bedtools ------------------
echo ""
echo "[$(timestamp)] Installing bedtools ..."
bedtools_dir="$build_dir/bedtools2/bin"
if [ -z $(check_installed $bedtools_dir) ]; then
    cd $build_dir
    clean "$build_dir/bedtools2"
    echo "Download bedtools-v${BEDTOOLS_VERSION}"
    download $BEDTOOLS_DOWNLOAD_URL "bedtools-${BEDTOOLS_VERSION}.tar.gz"
    tar xvzf bedtools-${BEDTOOLS_VERSION}.tar.gz
    cd "$build_dir/bedtools2"
    make -j $MAKE_JOBS
    cd $build_dir
    rm bedtools-${BEDTOOLS_VERSION}.tar.gz
    note_installed $bedtools_dir
fi

# --------------- gffread ------------------
echo ""
echo "[$(timestamp)] Installing gffread ..."
gffread_dir="$build_dir/gffread"
if [ -z $(check_installed $gffread_dir) ]; then
    cd $build_dir
    clean "$build_dir/gffread"
    echo "Download gffread-v${GFFREAD_VERSION}"
    download $GFFREAD_DOWNLOAD_URL "gffread-${GFFREAD_VERSION}.Linux_x86_64.tar.gz"
    tar xzf gffread-${GFFREAD_VERSION}.Linux_x86_64.tar.gz
    mv gffread-${GFFREAD_VERSION}.Linux_x86_64 gffread
    cd $build_dir
    rm gffread-${GFFREAD_VERSION}.Linux_x86_64.tar.gz
    note_installed $gffread_dir
fi

# --------------- MashMap ------------------
echo ""
echo "[$(timestamp)] Installing mashmap ..."
mashmap_dir="$build_dir/mashmap-Linux64-v${MASHMAP_VERSION}"
if [ -z $(check_installed $mashmap_dir) ]; then
    cd $build_dir
    clean "$build_dir/mashmap"
    echo "Download mashmap-v${MASHMAP_VERSION}"
    download $MASHMAP_DOWNLOAD_URL "mashmap-${MASHMAP_VERSION}.tar.gz"
    tar xvzf mashmap-${MASHMAP_VERSION}.tar.gz
    cd "$build_dir/mashmap-Linux64-v${MASHMAP_VERSION}"
    cd $build_dir
    rm mashmap-${MASHMAP_VERSION}.tar.gz
    note_installed $mashmap_dir
fi

# ------------- Salmon -------------------
echo ""
echo "[$(timestamp)] Installing Salmon ..."
salmon_dir="$build_dir/salmon-${SALMON_VERSION}_linux_x86_64/bin"
if [ -z $(check_installed $salmon_dir) ]; then
    cd $build_dir
    clean "$build_dir/salmon-${SALMON_VERSION}_linux_x86_64"
    echo "Download salmon-v${SALMON_VERSION}"
    download $SALMON_DOWNLOAD_URL salmon-${SALMON_VERSION}_linux_x86_64.tar.gz
    tar xzf salmon-${SALMON_VERSION}_linux_x86_64.tar.gz
    mv salmon-latest_linux_x86_64 salmon-${SALMON_VERSION}_linux_x86_64
    rm salmon-${SALMON_VERSION}_linux_x86_64.tar.gz
    note_installed $salmon_dir
fi

# --------------- Trimmomatic -----------------
echo ""
echo "[$(timestamp)] Installing Trimmomatic ..."
trimmomatic_dir="$build_dir/Trimmomatic-${TRIMMOMATIC_VERSION}"
if [ -z $(check_installed $trimmomatic_dir) ]; then
    cd $build_dir
    clean "$build_dir/Trimmomatic-${TRIMMOMATIC_VERSION}"
    echo "Download Trimmomatic-v${TRIMMOMATIC_VERSION}"
    download $TRIMMOMATIC_DOWNLOAD_URL "Trimmomatic-${TRIMMOMATIC_VERSION}.zip"
    unzip Trimmomatic-${TRIMMOMATIC_VERSION}.zip
    cd $trimmomatic_dir
    chmod 755 trimmomatic-${TRIMMOMATIC_VERSION}.jar
    ln -s trimmomatic-${TRIMMOMATIC_VERSION}.jar trimmomatic.jar 
    cd $build_dir
    rm Trimmomatic-${TRIMMOMATIC_VERSION}.zip
    note_installed $trimmomatic_dir
fi

# --------------- samtools -----------------
echo ""
echo "[$(timestamp)] Installing samtools ..."
samtools_dir="$build_dir/samtools-${SAMTOOLS_VERSION}"
htslib_dir="$samtools_dir/htslib-${HTSLIB_VERSION}"
tabix_dir="$samtools_dir/htslib-${HTSLIB_VERSION}"

if [ -z $(check_installed $samtools_dir) ]; then
    cd $build_dir
    clean "$build_dir/samtools-${SAMTOOLS_VERSION}"
    echo "Download samtools-v${SAMTOOLS_VERSION}"
    download $SAMTOOLS_DOWNLOAD_URL "samtools-${SAMTOOLS_VERSION}.tar.bz2"
    tar xvjf samtools-${SAMTOOLS_VERSION}.tar.bz2
    cd $samtools_dir
    C_INCLUDE_PATH=""
    ./configure --without-curses;
    make -j $MAKE_JOBS
    cd $htslib_dir
    ./configure
    make -j $MAKE_JOBS
    cd $build_dir
    rm samtools-${SAMTOOLS_VERSION}.tar.bz2
    note_installed $samtools_dir
fi
PATH="$samtools_dir:$htslib_dir:$tabix_dir:${PATH}"

# --------------- Picard -----------------
echo ""
echo "[$(timestamp)] Installing picard ..."
picard_dir="$build_dir/Picard-v${PICARD_VERSION}"
if [ -z $(check_installed $picard_dir) ]; then
    cd $build_dir
    clean "$build_dir/Picard-v${PICARD_VERSION}"
    echo "Download Picard-v${PICARD_VERSION}"
    download $PICARD_DOWNLOAD_URL "picard.jar"
    mkdir Picard-v${PICARD_VERSION}
    mv picard.jar $picard_dir
    cd $picard_dir
    chmod 755 picard.jar
    note_installed $picard_dir
fi

# --------------- parallel ------------------                                                                                                                        
echo ""
echo "[$(timestamp)] Installing parallel ..."
parallel_dir="$build_dir/parallel-${PARALLEL_VERSION}/bin"
if [ -z $(check_installed $parallel_dir) ]; then
    cd $build_dir
    clean "$build_dir/parallel-${PARALLEL_VERSION}"
    echo "Download parallel-${PARALLEL_VERSION}"
    download $PARALLEL_DOWNLOAD_URL "parallel_v${PARALLEL_VERSION}.tar.bz2"
    tar xvjf parallel_v${PARALLEL_VERSION}.tar.bz2
    cd parallel-${PARALLEL_VERSION}
    ./configure --prefix="$build_dir/parallel-${PARALLEL_VERSION}"
    make -j $MAKE_JOBS
    make install
    parallel_dir="$build_dir/parallel-${PARALLEL_VERSION}/bin"
    cd ..
    rm parallel_v${PARALLEL_VERSION}.tar.bz2
    note_installed $parallel_dir
fi



# Configure executable paths

cd $EVOSEQ_HOME
echo ""
echo "[$(timestamp)] Configuring executable paths ..."
echo "export EVOSEQ_HOME=${EVOSEQ_HOME}" > env.sh
echo "export build_dir=${build_dir}" >> env.sh
echo "export PERL5LIB=${PERL5LIB}" >> env.sh 
echo "export R_LIBS=${R_LIBS}" >> env.sh
echo "export cpanm_dir=${cpanm_dir}" >> env.sh
echo "export fastqc_dir=${fastqc_dir}" >> env.sh
echo "export multiqc_dir=${multiqc_dir}" >> env.sh
echo "export mashmap_dir=${mashmap_dir}" >> env.sh
echo "export salmon_dir=${salmon_dir}" >> env.sh
echo "export bedtools_dir=${bedtools_dir}" >> env.sh
#echo "export sra_dir=${sra_dir}" >> env.sh
echo "export trimmomatic_dir=${trimmomatic_dir}" >> env.sh
echo "export samtools_dir=${samtools_dir}" >> env.sh
echo "export picard_dir=${picard_dir}" >> env.sh
echo "export gffread_dir=${gffread_dir}" >> env.sh
echo "export parallel_dir=${parallel_dir}" >> env.sh



# test java configuration: requireds java 1.8 
echo ""
echo "##########################################"
echo "Testing java configuration ..."
echo ""
java_bin=""
if type -p java
then 
    java_bin=$(which java)
    echo "found java executable in PATH: $java_bin"
elif [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]]
then 
    java_bin="$JAVA_HOME/bin/java"
    echo "found java executable in JAVA_HOME: $java_bin" 
else 
    echo "";
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
    echo "Failed to detect Java installation in the system!"
    echo "Please install java 1.8, which is a dependency of EvoSeq!\n";
    echo "After the java installation, please manually set the directory path to java 1.8 executable on the last line of the env.sh file generated by this installation script!"
    echo "export java_dir=" >> env.sh
fi  

if [[ -n "$java_bin" ]]
then
    java_version=$("$java_bin" -version 2>&1 | awk -F '"' '/version/ {print $2}')
    echo "detected java_version: $java_version"
    if [ $(tidy_version "$java_version") -eq $(tidy_version "1.8") ]
    then
	java_dir=$(dirname $java_bin)
	echo "export java_dir=${java_dir}" >> env.sh
        echo "You have the correct java version for EvoSeq! EvoSeq will take care of the configuration."
    else
	echo "";
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
	echo "Your java version is not the version required by EvoSeq (java v1.8)!"
        echo "Please manually set the directory path to java 1.8 executable on the last line of the env.sh file generated by this installation script!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
	echo "export java_dir=" >> env.sh
    fi
fi

echo ""
echo "[$(timestamp)] Uncompress large supporting files ..."


echo "[$(timestamp)] Done!"
echo ""
echo ""
echo "#################### IMPORTANT !!! #######################"
echo ""
echo "[$(timestamp)] Automatic dependencies installation finished! "
echo ""
echo "#########################################################"


############################
# checking Bash exit status

if [ $? -eq 0 ]
then
    echo ""
    echo "EvoSeq_RNA  message: This bash script has been successfully processed! :)"
    echo ""
    echo ""
    exit 0
fi
############################
