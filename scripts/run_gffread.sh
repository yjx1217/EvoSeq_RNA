#/public/jxyue/Projects/EvoSeq_20230601/build/gffread/gffread YPS128.all_feature.gff -T --keep-genes -o YPS128.all_feature.gtf
perl ./../../scripts/gff2gtf.pl -i YPS128.all_feature.gff -o YPS128.all_feature.gtf
ln -s YPS128.genome.fa ref.genome.raw.fa
ln -s YPS128.all_feature.gtf ref.genome.raw.gtf 
