OPENSCAD=openscad
CONVERT=convert
SNAPPYVER="v3.0"
PARTFILES=$(sort $(wildcard *_parts.scad))
TARGETS=$(patsubst %.scad,3MFs/%.3mf,${PARTFILES})
ROTFILES=$(shell seq -f 'wiki/${SNAPPYVER}-snappy_rot%03g.png' 0 10 359.99)
ASM_MODULES=$(shell grep 'module [a-z0-9_]*_assembly' full_assembly.scad | sed 's/^module //' | sed 's/[^a-z0-9_].*$$//' | sed '1!G;h;$$!d')
ASM_BEFORE_TARGETS=$(patsubst %,docs/assembly/%_before.png,${ASM_MODULES})
ASM_AFTER_TARGETS=$(patsubst %,docs/assembly/%_after.png,${ASM_MODULES})

all: ${TARGETS}

3MFs/%.3mf: %.scad config.scad GDMUtils.scad
	@if grep -q '^\s*!' $< ; then echo "Found uncommented exclamation mark(s) in source." ; grep -Hn '^\s*!' $< ; false ; fi
	${OPENSCAD} -m make -o $@ $<

pull:
	git pull --recurse-submodules

clean:
	rm -f tmp_*.png tmp_*.scad wiki/${SNAPPYVER}-snappy_rot*.png

cleaner: clean
	rm -f ${TARGETS}

cleanwiki:
	rm -f wiki/${SNAPPYVER}-snappy_*.gif wiki/${SNAPPYVER}-snappy_*.png wiki/${SNAPPYVER}-*_parts.png

instructions: docs/assembly/index.html

docs/assembly/index.html: ${ASM_BEFORE_TARGETS} ${ASM_AFTER_TARGETS}
	./gen_assembly_index.py

${ASM_BEFORE_TARGETS}: full_assembly.scad
	echo "use <full_assembly.scad>" > $(patsubst docs/assembly/%.png,tmp_%.scad,$@)
	echo "$(patsubst docs/assembly/%_before.png,%,$@)(explode=100, arrows=true);" >> $(patsubst docs/assembly/%.png,tmp_%.scad,$@)
	${OPENSCAD} -o $(subst docs/assembly/,tmp_asm_,$@) \
	    --csglimit=2000000 --imgsize=3200,3200 --projection=p \
	    $(shell grep -A2 'module $(patsubst docs/assembly/%_before.png,%,$@)' full_assembly.scad | head -5 | grep '// *view:' | sed 's/[^]0-9.,]//g' | sed 's/[]]/,/g' | sed 's/^/--camera=/') \
	    --autocenter --viewall \
	    $(patsubst docs/assembly/%.png,tmp_%.scad,$@) 2<&1
	${CONVERT} -trim -resize 400x400 -border 10x10 -bordercolor '#ffffe5' $(subst docs/assembly/,tmp_asm_,$@) $@
	rm -f $(subst docs/assembly/,tmp_asm_,$@) $(patsubst docs/assembly/%.png,tmp_%.scad,$@)

${ASM_AFTER_TARGETS}: full_assembly.scad
	echo "use <full_assembly.scad>" > $(patsubst docs/assembly/%.png,tmp_%.scad,$@)
	echo "$(patsubst docs/assembly/%_after.png,%,$@)(explode=0, arrows=false);" >> $(patsubst docs/assembly/%.png,tmp_%.scad,$@)
	${OPENSCAD} -o $(subst docs/assembly/,tmp_asm2_,$@) \
	    --csglimit=2000000 --imgsize=3200,3200 --projection=p \
	    $(shell grep -A2 'module $(patsubst docs/assembly/%_after.png,%,$@)' full_assembly.scad | head -5 | grep '// *view:' | sed 's/[^]0-9.,]//g' | sed 's/[]]/,/g' | sed 's/^/--camera=/') \
	    --autocenter --viewall \
	    $(patsubst docs/assembly/%.png,tmp_%.scad,$@) 2<&1
	${CONVERT} -trim -resize 400x400 -border 10x10 -bordercolor '#ffffe5' $(subst docs/assembly/,tmp_asm2_,$@) $@
	rm -f $(subst docs/assembly/,tmp_asm2_,$@) $(patsubst docs/assembly/%.png,tmp_%.scad,$@)

${ROTFILES}: full_assembly.scad $(wildcard *.scad)
	${OPENSCAD} -o $(subst wiki/${SNAPPYVER}-,tmp_,$@) --imgsize=1024,1024 \
	    --projection=p --csglimit=2000000 \
	    -D '$$t=$(shell echo $(patsubst wiki/${SNAPPYVER}-snappy_rot%.png,%/360.0,$@) | bc -l)' \
	    -D '$$do_prerender=true' --camera=0,0,255,65,0,30,2200 $<
	${CONVERT} -strip -resize 512x512 $(subst wiki/${SNAPPYVER}-,tmp_,$@) $@
	rm -f  $(subst wiki/${SNAPPYVER}-,tmp_,$@)

wiki/${SNAPPYVER}-%.png: %.scad config.scad GDMUtils.scad
	${OPENSCAD} -o $(subst wiki/${SNAPPYVER}-,tmp_,$@) --render --imgsize=3200,3200 \
	    --projection=p --csglimit=2000000 --camera=0,0,50,65,0,30,2000 $<
	${CONVERT} -trim -resize 200x200 -border 10x10 -bordercolor '#ffffe5' $(subst wiki/${SNAPPYVER}-,tmp_,$@) $@
	rm -f $(subst wiki/${SNAPPYVER}-,tmp_,$@)

wiki/${SNAPPYVER}-snappy_full.png: full_assembly.scad $(wildcard *.scad)
	${OPENSCAD} -o $(subst wiki/${SNAPPYVER}-,tmp_,$@) --imgsize=3200,3200 --projection=p \
	    --csglimit=2000000 --camera=0,0,245,65,0,30,3000 -D '$$t=0.0' $<
	${CONVERT} -trim -resize 800x800 -border 10x10 -bordercolor '#ffffe5' $(subst wiki/${SNAPPYVER}-,tmp_,$@) $@
	rm -f $(subst wiki/${SNAPPYVER}-,tmp_,$@)

wiki/${SNAPPYVER}-snappy_small.png: wiki/${SNAPPYVER}-snappy_full.png
	${CONVERT} -trim -resize 200x200 -border 10x10 -bordercolor '#ffffe5' $< $@

wiki/${SNAPPYVER}-snappy_animated.gif: ${ROTFILES}
	${CONVERT} -delay 10 -loop 0 ${ROTFILES} $@
	rm -f ${ROTFILES}

wiki/${SNAPPYVER}-snappy_anim_small.gif: wiki/${SNAPPYVER}-snappy_animated.gif
	${CONVERT} -resize 200x200 $< $@

renderparts: $(patsubst %.scad,wiki/${SNAPPYVER}-%.png,${PARTFILES})
rendering: wiki/${SNAPPYVER}-snappy_full.png wiki/${SNAPPYVER}-snappy_small.png
animation: wiki/${SNAPPYVER}-snappy_animated.gif wiki/${SNAPPYVER}-snappy_anim_small.gif
wiki: rendering renderparts animation

# Dependencies follow.
3MFs/cable_chain_link_parts.3mf: joiners.scad
3MFs/cable_chain_mount_parts.3mf: joiners.scad
3MFs/cooling_fan_shroud_parts.3mf: joiners.scad
3MFs/drive_gear_parts.3mf: publicDomainGearV1.1.scad
3MFs/extruder_fan_clip_parts.3mf: joiners.scad
3MFs/extruder_fan_shroud_parts.3mf: joiners.scad
3MFs/extruder_idler_parts.3mf: joiners.scad
3MFs/extruder_motor_clip_parts.3mf: joiners.scad
3MFs/jhead_platform_parts.3mf: joiners.scad
3MFs/lifter_screw_parts.3mf: joiners.scad
3MFs/motor_mount_plate_parts.3mf: joiners.scad NEMA.scad
3MFs/platform_support_parts.3mf: joiners.scad
3MFs/rail_endcap_parts.3mf: joiners.scad
3MFs/rail_segment_parts.3mf: joiners.scad sliders.scad
3MFs/rail_xy_motor_segment_parts.3mf: joiners.scad sliders.scad
3MFs/rail_z_motor_segment_parts.3mf: joiners.scad
3MFs/rambo_mount_parts.3mf: joiners.scad
3MFs/ramps_mount_parts.3mf: joiners.scad
3MFs/skr14_mount_parts.3mf: joiners.scad
3MFs/sled_endcap_parts.3mf: joiners.scad
3MFs/slop_calibrator_parts.3mf: joiners.scad
3MFs/spool_holder_parts.3mf: joiners.scad
3MFs/support_leg_parts.3mf: joiners.scad
3MFs/xy_joiner_parts.3mf: joiners.scad
3MFs/xy_sled_parts.3mf: joiners.scad publicDomainGearV1.1.scad sliders.scad
3MFs/yz_joiner_parts.3mf: joiners.scad
3MFs/z_base_parts.3mf: joiners.scad
3MFs/z_rail_parts.3mf: joiners.scad acme_screw.scad
3MFs/z_sled_parts.3mf: joiners.scad
