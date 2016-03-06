cd Desktop/c

DEVICE=oneplus;

CPU=arm64;
FSTABLE=2684354560;

echo "Start to Build Miui ($DEVICE)"

if [ -d "workspace" ]; then
	echo "Cleaning Up..."
	sudo umount /dev/loop0
	rm -rf workspace $DEVICE-test-5.1.zip final/*
fi

mkdir -p workspace/output workspace/app stockrom final/system final/data/app

if [ ! -f "stockrom/system.new.dat" ]; then

  if [ ! -f "stockrom/boot.img" ];then
    exit
  else
    cp -rf stockrom/system workspace/
    cp -f stockrom/boot.img workspace/
    cp -f stockrom/file_contexts workspace/
    cp -rf tools/system.patch.dat stockrom/system.patch.dat
    export IMG=0
  fi

else

  if [ ! -f "stockrom/boot.img" ];then
    exit
  else
    cp -f stockrom/system.transfer.list workspace/
    cp -f stockrom/system.new.dat workspace/
    cp -f stockrom/boot.img workspace/
    cp -f stockrom/file_contexts workspace/
    export IMG=1
  fi

fi

cd workspace
echo "Modify Boot Image ..."
cp -rf ../tools/boot/* $PWD
./unpackimg.sh boot.img &> /dev/null

sed -i "/\s*ro.secureboot.devicelock.*$/d" ramdisk/default.prop
sed -i "/\s*system.*$/d" ramdisk/fstab.qcom
echo "/dev/block/bootdevice/by-name/system    /system            ext4    ro,barrier=1,discard                                wait" >>  ramdisk/fstab.qcom

#Add Oneplus File
cp -rf etc/* ramdisk/
cp -rf img/* split_img/

./repackimg.sh &> /dev/null
rm -rf bin dtbToolCM repackimg.sh unpackimg.sh etc img

if [ ${IMG} = 1 ]; then
  echo "Extract System.img ..."
  ./../tools/sdat2img.py system.transfer.list system.new.dat system.img &> /dev/null
  sudo mount -t ext4 -o loop system.img output/
  sudo chown -R nian:nian output
else
  echo "Copy System to Output ..."
  cp -rf ../stockrom/system/* output/
fi

if [ -d output/framework/$CPU ];then
	echo "Start Odex System ..."
	cp -rf ../tools/odex/* $PWD
	cp -rf output/* system/
	./deodex_lollipop
	rm -rf output/vendor/app/ims
	rm -rf output/framework
	rm -rf output/priv-app
	rm -rf output/app
	mv system/app output/
	mv system/framework output/
	mv system/priv-app output/
	mv system/vendor/app/ims output/vendor/app/
	rm -rf system
	rm -rf tools
	rm -rf deodex_lollipop
fi

echo "Start Modify APPS  ..."
cd app

mkdir -p ThemeManager_tmp miuisystem_tmp services_tmp android.policy_tmp

cp -rf ../../tools/apktool* $PWD
cp -rf ../../tools/git.apply $PWD
cp -rf ../../tools/rmline.sh $PWD

cp -rf ../output/app/ThemeManager/ThemeManager.apk ThemeManager.apk
cp -rf ../output/app/miuisystem/miuisystem.apk miuisystem.apk
cp -rf ../output/framework/services.jar services.jar
cp -rf ../output/framework/android.policy.jar android.policy.jar
./apktool d miuisystem.apk &> /dev/null
./apktool d ThemeManager.apk &> /dev/null
./apktool d services.jar &> /dev/null
./apktool d android.policy.jar &> /dev/null
./git.apply  ../../tools/1.patch
./git.apply  ../../tools/2.patch
./git.apply  ../../tools/3.patch
./apktool b miuisystem &> /dev/null
./apktool b ThemeManager &> /dev/null
./apktool b services.jar.out &> /dev/null
./apktool b android.policy.jar.out &> /dev/null

mv services.jar.out/dist/services.jar ../output/framework/
mv android.policy.jar.out/dist/android.policy.jar ../output/framework/

mv ThemeManager.apk ThemeManager_tmp/ThemeManager.zip
cd ThemeManager_tmp
unzip ThemeManager.zip &> /dev/null
cp -rf ../ThemeManager/build/apk/classes.dex classes.dex
zip -q -r "../../output/app/ThemeManager/ThemeManager.apk" 'assets' 'META-INF' 'resources.arsc' 'res' 'AndroidManifest.xml' 'classes.dex' &> /dev/null
cd ..

mv miuisystem.apk miuisystem_tmp/miuisystem.zip
cd miuisystem_tmp
unzip miuisystem.zip &> /dev/null
cp -rf ../miuisystem/build/apk/classes.dex classes.dex
zip -q -r "../../output/app/miuisystem/miuisystem.apk" 'assets' 'META-INF' 'resources.arsc' 'res' 'AndroidManifest.xml' 'classes.dex' &> /dev/null
cd ..

rm -rf *
cd ..

echo "Start Modify System ..."
echo "Bye AD ..."
cp -rf ../tools/etc/* output/etc/
rm -rf output/app/GooglePinyinIME output/app/SystemAdSolution output/app/LatinImeGoogle output/priv-app/MiuiCamera

echo "Add StockSettings ..."
cp -rf ../tools/third output/media/theme/
cp -rf ../tools/app/* output/priv-app/

echo "Disable Recovery Auto Install ..."
rm -rf output/recovery-from-boot.p
rm -rf output/bin/install-recovery.sh

echo "Start Oneplus Port"
cp -rf ../tools/oneplus/* output/
sed -i -e "s/ro\.build\.product=.*/ro\.build\.product=tocino/g" output/build.prop
sed -i -e "s/ro\.product\.device=.*/ro\.product\.device=tocino/g" output/build.prop
sed -i -e "s/ro\.product\.model=.*/ro\.product\.model=ONE A2001/g" output/build.prop
sed -i -e "s/ro\.product\.name=.*/ro\.product\.name=tocino/g" output/build.prop
sed -i -e "s/ro\.product\.brand=.*/ro\.product\.brand=OnePlus/g" output/build.prop
sed -i -e "s/ro\.build\.description=.*/ro\.build\.description=OnePlus2-user 5.1.1 LMY47V 21 dev-keys/g" output/build.prop
sed -i -e "s/ro\.build\.fingerprint=.*/ro\.build\.fingerprint=OnePlus\/OnePlus2\/OnePlus2:5.1.1\/LMY47V\/1436933040:user\/release-keys/g" output/build.prop

echo "Tweak build.prop"
sed -i "/\s*ro.sf.lcd_density.*$/d" output/build.prop
echo "ro.sf.lcd_density=480" >>  output/build.prop

echo "Add Xposed ..."
cp -rf ../tools/xposed/* output/

echo "Build system.new.dat ..."
./../tools/make_ext4fs -T 0 -S file_contexts -l $FSTABLE -a system system_new.img output/ &> /dev/null
./../tools/rimg2sdat system_new.img &> /dev/null

cd ../

echo "Final Step ..."

if [ ${IMG} = 1 ]; then
  cp -rf tools/META-INF final/META-INF
else
  cp -rf tools/META-INF2 final/META-INF
fi


mv workspace/boot.img final/
mv workspace/system.new.dat final/
mv workspace/system.transfer.list final/
cp -rf stockrom/system.patch.dat final/
cp -rf tools/file_contexts final/
cp -rf tools/firmware-update final/
cp -rf tools/RADIO final/
cp -rf stockrom/data final/
rm -rf final/data/miui/app/customized/ota-partner-GooglePinyin-arm64

if [ -d tools/third-app ];then
	echo "Add Third App ..."
	cp -rf tools/third-app/* final/data/app/
fi

cd final
zip -q -r "../$DEVICE-test-5.1.zip" 'boot.img' 'META-INF' 'system.new.dat' 'system.transfer.list' 'system.patch.dat' 'file_contexts' 'firmware-update'  'system'  'data' 'RADIO'
cd ..

sudo umount /dev/loop0
rm -rf workspace final/*
cd
