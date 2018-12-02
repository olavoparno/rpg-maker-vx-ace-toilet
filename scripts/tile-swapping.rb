=begin
================================================================================
  Title: Tile Swap
 Author: Hime, Rycochet
   Date: Jun 11, 2014
--------------------------------------------------------------------------------
 ** Change log
 3.3
   - added support for auto-tiles on layer 2
 3.2 Jun 8, 2014
   - fixed issue where pos reverting was sliding tiles over
 3.1 Jan 16, 2014
   - renamed flag to "need_refresh_tiles" and exposed as a reader
 3.0 --- WIP
	 -TODO auto-layer from "A13" style tile id
	 -TODO documentation update, including the new Map_Mask usage
 3.0b1 September 20 2013 by Rycochet
	 -Added Map_Mask class and several shape functions - can replace everything
	  except positions if needed
	 -Various bugfixes and speedups
 2.5 September 19 2013 by Rycochet
	 -Yet more speedups, can now handle an entire 250k map in under 2 seconds
	 -Fixed accidental bug in convert_tid
 2.4 September 17 2013 by Rycochet
	 -major performance boosts, dirty map change flag, bitfield mask
 2.3 May 5
	 -fixed bug where A5 tiles were not being swapped properly. This is because
		they were treated as auto-tiles instead of normal tiles
 2.2 May 4
	 -updated to support overlay maps
 2.1 Apr 11
	 -fixed bug where B-E pages weren't handled properly
 2.0 Feb 17
	 -removed use of a new map. Should be more compatible now
	 -fixed bug where last row of page A4 tiles were skipped
	 -revised input format
	 -proper autotile swapping
 1.2 Jan 22, 2013
	 -fixed bug where swap by position didn't handle layers properly
 1.1 May 20
	 -Added support for reverting tiles
 1.0 May 16, 2012
	 -Initial release
--------------------------------------------------------------------------------
 ** Terms of Use
 * Free to use in non-commercial projects
 * Contact me for commercial use
 * The script is provided as-is
 * Cannot guarantee that it is compatible with other scripts
 * Preserve this header
--------------------------------------------------------------------------------
 ** Description

 This script allows you to change the tiles on a map, and also revert the
 changes.
--------------------------------------------------------------------------------
 ** Compatibility

 Let me know.
--------------------------------------------------------------------------------
 ** Usage

 Please refer to the reference section to understand what a tileID is and
 how these script calls should be made.

 There are three types of tile swaps

 1. Change by tile id
	 -All tiles on the map with the specified ID will be changed to a new tile

		Usage: tile_swap(old_tileID, new_tileID, layer, map_id)

 2. Change by region id
	 -All tiles that are covered by the specified region ID will be changed
		to a new tile

		Usage: region_swap(regionID, tileID, layer, map_id)

 3. Change by position
	 -The tile at the specified position will be changed to a new tile

		Usage: pos_swap(x, y, tileID, layer, map_id)

 You can undo tile swaps using analogous functions

	 tile_revert(tid, layer, map_id)
	 pos_revert(x, y, layer, map_id)
	 region_revert(rid, layer, map_id)
	 revert_all(map_id)

--------------------------------------------------------------------------------
 ** Reference

 This script uses the concept of a "tile ID", which is a special string
 that represents a particular tile on your tileset.

 The format of this tile ID is a letter, followed by a number.
 The letters available are based on the tileset names

	 A, B, C, D, E

 The number represents the ID of the tile.
 So for example, "A1" would be the the first tile in tileset A, whereas
 "B12" would be the 12th tile of tileset B.

 To determine the ID of a tile, it is easy: simply look at your tileset and
 number the top-left tile as 1. Then, number them from left-to-right,
 top-to-bottom as such

	 1  2  3  4  5  6  7  8
	 9 10 11 12 13 14 15 16
	 ...

 The ID that you want is exactly as it appears on your tileset.
--------------------------------------------------------------------------------
 ** Credits

 KilloZapit, for the excellent auto-tile generation code
================================================================================
=end
$imported = {} if $imported.nil?
$imported["TH_TileSwap"] = true
#===============================================================================
# ** Rest of the script.
#===============================================================================

class Game_System

	attr_accessor :swapped_tiles, :swapped_pos_tiles, :swapped_region_tiles, :swapped_mask_tiles

	#-----------------------------------------------------------------------------
	# New. Convert my tileID to an internal tile ID.
	# If passed an [x,y] array then get a tile from the current map instead.
	#-----------------------------------------------------------------------------
	def convert_tid(tileID, layer=0)
		return $game_map.tile_id(tileID[0], tileID[1], layer) if tileID.kind_of?(Array)
		page = tileID[0].upcase
		tid = tileID[1..-1].to_i - 1
		if page == 'A'
			# page A has autotiles
			return tid * 48 + 2048 if tid < 128
			return tid - 128 + 1536
		end
		# pages B, C, D, and E all have 256 icons per page.
		return tid if page == 'B'
		return tid + 256 if page == 'C' # 1 x 256
		return tid + 512 if page == 'D' # 2 x 256
		return tid + 768 if page == 'E' # 3 x 256
	end

	#==============================================================================
	# ■ Tiles
	#==============================================================================

	#-----------------------------------------------------------------------------
	# New.
	#-----------------------------------------------------------------------------
	def initialize_tile_list(map_id, layer)
		@swapped_tiles = [] if @swapped_tiles.nil?
		@swapped_tiles[map_id] = [] if @swapped_tiles[map_id].nil?
		@swapped_tiles[map_id][layer] = [] if @swapped_tiles[map_id][layer].nil?
	end

	#-----------------------------------------------------------------------------
	# New.
	#-----------------------------------------------------------------------------
	def add_tile_id(map_id, layer, old_tid, new_tid)
		initialize_tile_list(map_id, layer)
		old_tid = convert_tid(old_tid, layer)
		new_tid = convert_tid(new_tid, layer)
		@swapped_tiles[map_id][layer][old_tid] = new_tid
		$game_map.load_new_map_data
	end

	#-----------------------------------------------------------------------------
	# New.
	#-----------------------------------------------------------------------------
	def has_swap_tiles?(map_id, layer)
		return false if @swapped_tiles.nil?
		return false if @swapped_tiles[map_id].nil? || @swapped_tiles[map_id].empty?
		return false if @swapped_tiles[map_id][layer].nil? || @swapped_tiles[map_id][layer].empty?
		return true
	end

	#-----------------------------------------------------------------------------
	# New. Remove all custom tiles on the map for a given layer and tileID
	#-----------------------------------------------------------------------------
	def revert_tile(map_id, layer, tid)
		initialize_tile_list(map_id, layer)
		tid = convert_tid(tid, layer)
		@swapped_tiles[map_id][layer].delete_at(tid)
		$game_map.reload_map
	end

	#==============================================================================
	# ■ Positions
	#==============================================================================

	#-----------------------------------------------------------------------------
	# New.
	#-----------------------------------------------------------------------------
	def initialize_pos_list(map_id, layer)
		@swapped_pos_tiles = [] if @swapped_pos_tiles.nil?
		@swapped_pos_tiles[map_id] = [] if @swapped_pos_tiles[map_id].nil?
		@swapped_pos_tiles[map_id][layer] = [] if @swapped_pos_tiles[map_id][layer].nil?
	end

	#-----------------------------------------------------------------------------
	# New.
	#-----------------------------------------------------------------------------
	def add_position_tile(map_id, x, y, layer, tid)
		initialize_pos_list(map_id, layer)
		tid = convert_tid(tid, layer)
		@swapped_pos_tiles[map_id][layer][y] = [] if @swapped_pos_tiles[map_id][layer][y].nil?
		@swapped_pos_tiles[map_id][layer][y][x] = tid
		$game_map.load_new_map_data
	end

	#-----------------------------------------------------------------------------
	# New.
	#-----------------------------------------------------------------------------
	def has_swap_pos?(map_id, layer)
		return false if @swapped_pos_tiles.nil?
		return false if @swapped_pos_tiles[map_id].nil? || @swapped_pos_tiles[map_id].empty?
		return false if @swapped_pos_tiles[map_id][layer].nil? || @swapped_pos_tiles[map_id][layer].empty?
		return true
	end

	#-----------------------------------------------------------------------------
	# New. Remove all custom tiles on the map for a given layer and position
	#-----------------------------------------------------------------------------
	def revert_pos(map_id, x, y, layer)
		initialize_pos_list(map_id, layer)
		unless @swapped_pos_tiles[map_id][layer][y].nil?
			@swapped_pos_tiles[map_id][layer][y][x] = nil
			@swapped_pos_tiles[map_id][layer].delete_at(y) if @swapped_pos_tiles[map_id][layer][y].empty?
		end
		$game_map.reload_map
	end

	#==============================================================================
	# ■ Regions
	#==============================================================================

	#-----------------------------------------------------------------------------
	# New.
	#-----------------------------------------------------------------------------
	def initialize_region_list(map_id, layer)
		@swapped_region_tiles = [] if @swapped_region_tiles.nil?
		@swapped_region_tiles[map_id] = [] if @swapped_region_tiles[map_id].nil?
		@swapped_region_tiles[map_id][layer] = [] if @swapped_region_tiles[map_id][layer].nil?
	end

	#-----------------------------------------------------------------------------
	# New.
	#-----------------------------------------------------------------------------
	def add_region_tile(map_id, rid, layer, tid)
		initialize_region_list(map_id, layer)
		tid = convert_tid(tid, layer)
		@swapped_region_tiles[map_id][layer][rid] = tid
		$game_map.load_new_map_data
	end

	#-----------------------------------------------------------------------------
	# New.
	#-----------------------------------------------------------------------------
	def has_swap_region?(map_id, layer)
		return false if @swapped_region_tiles.nil?
		return false if @swapped_region_tiles[map_id].nil? || @swapped_region_tiles[map_id].empty?
		return false if @swapped_region_tiles[map_id][layer].nil? || @swapped_region_tiles[map_id][layer].empty?
		return true
	end

	#-----------------------------------------------------------------------------
	# New. Remove all custom tiles on the map for a given layer and region
	#-----------------------------------------------------------------------------
	def revert_region(map_id, layer, rid)
		initialize_region_list(map_id, layer)
		@swapped_region_tiles[map_id][layer].delete_at(rid)
		$game_map.reload_map
	end

	#==============================================================================
	# ■ Masks
	#==============================================================================

	#-----------------------------------------------------------------------------
	# New.
	#-----------------------------------------------------------------------------
	def initialize_mask_list(map_id, layer)
		@swapped_mask_tiles = [] if @swapped_mask_tiles.nil?
		@swapped_mask_tiles[map_id] = [] if @swapped_mask_tiles[map_id].nil?
		@swapped_mask_tiles[map_id][layer] = {} if @swapped_mask_tiles[map_id][layer].nil?
	end

	#-----------------------------------------------------------------------------
	# New.
	#-----------------------------------------------------------------------------
	def add_mask_tile(map_id, mask, layer, tid)
		initialize_mask_list(map_id, layer)
		tid = convert_tid(tid, layer)
		@swapped_mask_tiles[map_id][layer][mask] = tid
		$game_map.load_new_map_data
	end

	#-----------------------------------------------------------------------------
	# New.
	#-----------------------------------------------------------------------------
	def has_swap_mask?(map_id, layer)
		return false if @swapped_mask_tiles.nil?
		return false if @swapped_mask_tiles[map_id].nil? || @swapped_mask_tiles[map_id].empty?
		return false if @swapped_mask_tiles[map_id][layer].nil? || @swapped_mask_tiles[map_id][layer].empty?
		return true
	end

	#-----------------------------------------------------------------------------
	# New. Remove all custom tiles on the map for a given layer and region
	#-----------------------------------------------------------------------------
	def revert_mask(map_id, layer, mask)
		initialize_mask_list(map_id, layer)
		@swapped_mask_tiles[map_id][layer].delete(mask)
		$game_map.reload_map
	end

	#==============================================================================
	# ■ Revert All
	#==============================================================================

	#-----------------------------------------------------------------------------
	# New. Remove all custom tiles from the given map
	#-----------------------------------------------------------------------------
	def revert_all(map_id)
		@swapped_tiles[map_id] = nil unless @swapped_tiles.nil?
		@swapped_pos_tiles[map_id] = nil unless @swapped_pos_tiles.nil?
		@swapped_mask_tiles[map_id] = nil unless @swapped_mask_tiles.nil?
		@swapped_region_tiles[map_id] = nil unless @swapped_region_tiles.nil?
		$game_map.reload_map
	end
end

class Map_Mask
	attr_accessor :width, :height, :priority
	#attr @mask # array, each row is in reverse order, bit 0 is the left-most bit
	#attr @mask_width # 0b1111111 - a mask to & with a row to ensure it stays within the width

	def initialize(max_width, max_height, priority = 0)
		@width = max_width
		@height = max_height
		@priority = priority
		@mask_width = (1 << max_width) - 1
		clear!
	end

	#--------------------------------------------------------------------------
	# * !! Print the mask for debugging !!
	#--------------------------------------------------------------------------
	def debug
		print "Current mask:\n"
		for y in 0...@height
			print "#{(@mask[y] || 0).to_s(2).reverse}\n"
		end
	end

	#--------------------------------------------------------------------------
	# * update
	# Updates the map
	#--------------------------------------------------------------------------
	def update
#		$game_map.load_new_map_data
		$game_map.reload_map
	end

	#--------------------------------------------------------------------------
	# * valid?(x, y)
	# Check if a coordinate is valid
	#--------------------------------------------------------------------------
	def valid?(x, y)
		return x >= 0 && x < @width && y >= 0 && y < @height
	end

	#--------------------------------------------------------------------------
	# * empty?
	# Checks if the mask is empty
	#--------------------------------------------------------------------------
	def empty?
		return true if @mask.empty?
		for y in 0...@height
			return false if @mask[y]
		end
		return true
	end

	#--------------------------------------------------------------------------
	# * clear!
	# Clears the entire mask
	#--------------------------------------------------------------------------
	def clear!
		@mask = []
	end

	#--------------------------------------------------------------------------
	# * []=(x, y)
	# Marks or clears a single coordinate in the mask
	# Access as an array, but with a true/false value type
	#--------------------------------------------------------------------------
	def []=(x, y, set)
		return unless valid?(x, y)
		if set
			@mask[y] = ((@mask[y] || 0) | (1 << x)) & @mask_width
		else
			@mask[y] = (@mask[y] || 0) & (@mask_width ^ (1 << x))
		end
	end

	#--------------------------------------------------------------------------
	# * [](x, y)
	# Checks if a single coordinate in the mask is set
	#--------------------------------------------------------------------------
	def [](x, y)
		return (@mask[y] || 0) & (1 << x) != 0
	end

	#--------------------------------------------------------------------------
	# * **(y)
	# Get the full line data for a single row
	#--------------------------------------------------------------------------
	def **(y)
		return (@mask[y] || 0)
	end
	
	#--------------------------------------------------------------------------
	# * or(mask)
	# OR with another mask, tiles that are set in either mask will be kept
	#--------------------------------------------------------------------------
	def or(mask)
		for y in 0...[mask.height, @height].min
			@mask[y] = ((@mask[y] || 0) | (mask ** y)) & @mask_width
		end
	end

	#--------------------------------------------------------------------------
	# * xor(mask)
	# XOR with another mask, only tiles that are set in a single mask will be
	# kept
	#--------------------------------------------------------------------------
	def xor(mask)
		for y in 0...[mask.height, @height].min
			@mask[y] = ((@mask[y] || 0) ^ (mask ** y)) & @mask_width
		end
	end

	#--------------------------------------------------------------------------
	# * and(mask)
	# AND with another mask, only tiles that are set in both masks will be kept
	#--------------------------------------------------------------------------
	def and(mask)
		for y in 0...[mask.height, @height].min
			@mask[y] = ((@mask[y] || 0) & (mask ** y)) & @mask_width
		end
	end

	#--------------------------------------------------------------------------
	# * invert
	# Inverts a mask
	#--------------------------------------------------------------------------
	def invert
		for y in 0...@height
			@mask[y] = (@mask[y] || 0) ^ @mask_width
		end
	end

	#--------------------------------------------------------------------------
	# * copy(mask)
	# Copy another mask
	#--------------------------------------------------------------------------
	def copy(mask)
		clear!
		for y in 0...[mask.height, @height].min
			@mask[y] = (mask ** y) & @mask_width
		end
	end

	#--------------------------------------------------------------------------
	# * from_region(rid)
	# Copy a region from the current map
	#--------------------------------------------------------------------------
	def from_region(rid)
		for y in 0...[@height, $game_map.height].min
			for x in 0...[@width, $game_map.width].min
				if rid == $game_map.data[x, y, 3] >> 8
					@mask[y] = ((@mask[y] || 0) | (1 << x)) # @mask[x,y] = true
				end
			end
		end
	end

	#--------------------------------------------------------------------------
	# * from_tile(tid)
	# Copy a tile mask from the current map - uses autotile generic tiles
	#--------------------------------------------------------------------------
	def from_tile(tid, layer = 0)
		tid = $game_system.convert_tid(tid)
		for y in 0...[@height, $game_map.height].min
			for x in 0...[@width, $game_map.width].min
				old_tid = $game_map.data[x, y, layer]
				old_tid = old_tid - ((old_tid - 2048) % 48) if old_tid >= 2048
				if tid == old_tid
					@mask[y] = ((@mask[y] || 0) | (1 << x)) # @mask[x,y] = true
				end
			end
		end
	end

	#--------------------------------------------------------------------------
	# * rectangle(width, height, left, top)
	# Draw a rectangle in the mask
	#--------------------------------------------------------------------------
	def rectangle(width, height, left = 0, top = 0)
		mask = (((1 << (width + 1)) - 1) << left) & @mask_width
		for y in top...[(top + width), @height].min
			@mask[y] = (@mask[y] || 0) | mask
		end
	end

	#--------------------------------------------------------------------------
	# * shift(right, down)
	# Shift a mask, use negative numbers for left / up
	#--------------------------------------------------------------------------
	def shift(right, down)
		mask = []
		for y in 0...@height
			if @mask[y + down]
				if !right
					mask[y] = @mask[y + down]
				elsif right < 0
					mask[y] = @mask[y + down] >> -right
				elsif right > 0
					mask[y] = (@mask[y + down] << right) & @mask_width
				end
			end
		end
		@mask = mask
	end

	#--------------------------------------------------------------------------
	# * grow
	# Grow the outline of a mask, every filled coordinate is surrounded in a
	# 3x3 grid
	#--------------------------------------------------------------------------
	def grow
		mask = []
		for y in 0...@height
			if @mask[y]
				mask[y] = @mask[y] |= (@mask[y] << 1) | (@mask[y] >> 1)
			end
			if y > 0
				mask[y-1] = (mask[y-1] || 0) | @mask[y] unless @mask[y].nil?
				mask[y] = (mask[y] || 0) | @mask[y-1] unless @mask[y-1].nil?
			end
		end
		@mask = mask
	end

	#--------------------------------------------------------------------------
	# * shrink
	# Shrink the outline of a mask, will reduce the size of a mask in a * shape
	#--------------------------------------------------------------------------
	def shrink
		invert
		grow
		invert
	end

	#--------------------------------------------------------------------------
	# * blur
	# Similar to grow, but doesn't grow diagonally
	#--------------------------------------------------------------------------
	def blur
		mask = []
		for y in 0...@height
			if @mask[y]
				mask[y] = @mask[y] | (@mask[y] << 1) | (@mask[y] >> 1)
			end
			if y > 0
				mask[y-1] = (mask[y-1] || 0) | @mask[y] unless @mask[y].nil?
				mask[y] = (mask[y] || 0) | @mask[y-1] unless @mask[y-1].nil?
			end
		end
		@mask = mask
	end

	#--------------------------------------------------------------------------
	# * unblur
	# Shrink the outline of a mask, will reduce the size of a mask in a + shape
	#--------------------------------------------------------------------------
	def unblur
		invert
		blur
		invert
	end

	#--------------------------------------------------------------------------
	# * each {|x, y, valid_left, valid_top, valid_right, valid_bottom| ... }
	# Perform operations on every valid square in the mask, the valid_*
	# variables state whether the coordinate is against the edge (in a more
	# efficient manner)
	#--------------------------------------------------------------------------
	def each
		for y in 0...@height
			next if !@mask[y]
			valid_top = y > 0
			valid_bottom = y < @height-1
			val = @mask[y]
			for x in 0...@width
				break if !val
				unless val & 1 == 0
					valid_left = x > 0
					valid_right = x < @width-1
					yield x, y, valid_left, valid_top, valid_right, valid_bottom
				end
				val >>= 1
			end
		end
	end
end

class Game_Map

  attr_reader :need_refresh_tiles

	#-----------------------------------------------------------------------------
	# Aliased. Load new map data after the original map is loaded
	#-----------------------------------------------------------------------------
	alias :tsuki_tile_swap_setup_map :setup
	def setup(map_id)
		tsuki_tile_swap_setup_map(map_id)
		@updated_tiles = Map_Mask.new(width, height)
		load_new_map_data
	end

	#-----------------------------------------------------------------------------
	# New. Grab the original map data and load that up
	#-----------------------------------------------------------------------------
	def reload_map
		new_map = load_data(sprintf("Data/Map%03d.rvdata2", @map_id))
		@map.data = new_map.data
		load_new_map_data
	end

	#-----------------------------------------------------------------------------
	# New. Load custom map data on top of our map
	#-----------------------------------------------------------------------------
	def load_new_map_data
		@need_refresh_tiles = true
	end
  
  #-----------------------------------------------------------------------------
  # New. Swap tiles by tile ID
  #-----------------------------------------------------------------------------
  def perform_load_new_map_data  
    @need_refresh_tiles = false
    for z in 0...3
      @updated_tiles.clear!
      tiles = $game_system.has_swap_tiles?(@map_id, z) ? $game_system.swapped_tiles[map_id][z] : nil
      regions = $game_system.has_swap_region?(@map_id, z) ? $game_system.swapped_region_tiles[map_id][z] : nil
      masks = $game_system.has_swap_mask?(@map_id, z) ? $game_system.swapped_mask_tiles[map_id][z] : nil
      position_tiles = $game_system.has_swap_pos?(@map_id, z) ? $game_system.swapped_pos_tiles[map_id][z] : nil
      next unless tiles or masks or regions or position_tiles
      for y in 0...height
        positions = position_tiles.nil? ? nil : position_tiles[y]
        for x in 0...width
          new_tile = nil
          if positions
            new_tile = positions[x]
          end
          if new_tile.nil? and masks
            priority = nil
            masks.each {|mask, tid|
              if (priority.nil? or mask.priority > priority) and mask[x,y]
                new_tile = tid
                priority = mask.priority
              end
            }
          end
          if new_tile.nil? and regions
            new_tile = regions[tile_id(x, y, 3) >> 8] # region_id(x,y) - but without the extra valid?(x,y) overhead
          end
          if new_tile.nil? and tiles
            old_tid = tile_id(x, y, z)
            old_tid = old_tid - ((old_tid - 2048) % 48) if old_tid >= 2048
            new_tile = tiles[old_tid]
          end
          next if new_tile.nil?
          old_tid = tile_id(x, y, z)
          old_tid = old_tid - ((old_tid - 2048) % 48) if old_tid >= 2048
          next if new_tile == old_tid # quicker than the autotile recalibration overhead for a single tile
          @map.data[x, y, z] = new_tile
          @updated_tiles[x, y] = true
        end
      end
      @updated_tiles.grow
      #-----------------------------------------------------------------------------
      # The following was originally based on auto-tile generation code by KilloZapit
      #-----------------------------------------------------------------------------
      @updated_tiles.each { |x, y, valid_left, valid_top, valid_right, valid_bottom|
        autotile = (tile_id(x, y, z) - 2048) / 48
        next if autotile < 0
        index = 0
        if autotile == 5 or autotile == 7 or autotile == 9 or autotile == 11 or autotile == 13 or autotile == 15
          # waterfall
          index |= 1 if valid_left && autotile_edge(autotile, x - 1, y, z)
          index |= 2 if valid_right && autotile_edge(autotile, x + 1, y, z)
        elsif autotile >= 48 and autotile <= 79 or autotile >= 88 and autotile <= 95 or autotile >= 104 and autotile <= 111 or autotile >= 120 and autotile <= 127
          # wall
          index |= 1 if valid_left && autotile_wall_edge(autotile, x - 1, y, z)
          index |= 2 if valid_top && autotile_edge(autotile, x, y - 1, z)
          index |= 4 if valid_right && autotile_wall_edge(autotile, x + 1, y, z)
          index |= 8 if valid_bottom && autotile_edge(autotile, x, y + 1, z)
        else
          # normal
          edge = 0
          edge |= 1 if valid_left && autotile_edge(autotile, x - 1, y, z)
          edge |= 2 if valid_top && autotile_edge(autotile, x, y - 1, z)
          edge |= 4 if valid_right && autotile_edge(autotile, x + 1, y, z)
          edge |= 8 if valid_bottom && autotile_edge(autotile, x, y + 1, z)
          if edge == 0 # -
            index |= 1 if valid_top && valid_left && autotile_edge(autotile, x - 1, y - 1, z)
            index |= 2 if valid_top && valid_right && autotile_edge(autotile, x + 1, y - 1, z)
            index |= 4 if valid_bottom && valid_right && autotile_edge(autotile, x + 1, y + 1, z)
            index |= 8 if valid_bottom && valid_left && autotile_edge(autotile, x - 1, y + 1, z)
          elsif edge == 1 # l
            index |= 1 if valid_top && valid_right && autotile_edge(autotile, x + 1, y - 1, z)
            index |= 2 if valid_bottom && valid_right && autotile_edge(autotile, x + 1, y + 1, z)
            index |= 16
          elsif edge == 2 # u
            index |= 1 if valid_bottom && valid_right && autotile_edge(autotile, x + 1, y + 1, z)
            index |= 2 if valid_bottom && valid_left && autotile_edge(autotile, x - 1, y + 1, z)
            index |= 20
          elsif edge == 3 # lu
            index = valid_bottom && valid_right && autotile_edge(autotile, x + 1, y + 1, z) ? 35 : 34
          elsif edge == 4 # r
            index |= 1 if valid_bottom && valid_left && autotile_edge(autotile, x - 1, y + 1, z)
            index |= 2 if valid_top && valid_left && autotile_edge(autotile, x - 1, y - 1, z)
            index |= 24
          elsif edge == 5 # lr
            index = 32
          elsif edge == 6 # ur
            index = valid_bottom && valid_left && autotile_edge(autotile, x - 1, y + 1, z) ? 37 : 36
          elsif edge == 7 # lur
            index = 42
          elsif edge == 8 # d
            index |= 1 if valid_top && valid_left && autotile_edge(autotile, x - 1, y - 1, z)
            index |= 2 if valid_top && valid_right && autotile_edge(autotile, x + 1, y - 1, z)
            index |= 28
          elsif edge == 9 # ld
            index = valid_top && valid_right && autotile_edge(autotile, x + 1, y - 1, z) ? 41 : 40
          elsif edge == 10 # ud
            index = 33
          elsif edge == 11 # lud
            index = 43
          elsif edge == 12 # rd
            index = valid_top && valid_left && autotile_edge(autotile, x - 1, y - 1, z) ? 39 : 38
          elsif edge == 13 # lrd
            index = 44
          elsif edge == 14 # urd
            index = 45
          elsif edge == 15 # lurd
            index = 46
          else # wtf
            index = 47
          end
        end
        @map.data[x, y, z]= 2048 + (48 * autotile) + index
      }
    end
  end

	#-----------------------------------------------------------------------------
	# Aliased. Refresh the map if we've got pending changes
	#-----------------------------------------------------------------------------
	alias :tsuki_tile_swap_update_map :update
	def update(main = false)
		if @need_refresh_tiles
      perform_load_new_map_data
		end
		tsuki_tile_swap_update_map(main)
	end

	# Special dungeon logic
	# makes overlay grass tiles "grow" out of walls.
	def autotile_edge(autotile, x, y, z)
		return autotile != (tile_id(x, y, z) - 2048) / 48
	end

	def autotile_wall_edge(autotile, x, y, z)
		return false if autotile & 8 and (tile_id(x, y, z) - 2048) / 48 + 8 == autotile
		return autotile_edge(autotile, x, y, z)
	end
end

class Game_Interpreter

	#swaps the tile at x,y to the specified tile_id
	def tile_swap(old_tid, new_tid, layer=0, map_id=$game_map.map_id)
		$game_system.add_tile_id(map_id, layer, old_tid, new_tid)
	end

	def pos_swap(x, y, tid, layer=0, map_id=$game_map.map_id)
		$game_system.add_position_tile(map_id, x, y, layer, tid)
	end

	def region_swap(rid, tid, layer=0, map_id=$game_map.map_id)
		$game_system.add_region_tile(map_id, rid, layer, tid)
	end

	def mask_swap(mask, tid, layer=0, map_id=$game_map.map_id)
		$game_system.add_mask_tile(map_id, mask, layer, tid)
	end

	def tile_revert(tid, layer=0, map_id=$game_map.map_id)
		$game_system.revert_tile(map_id, layer, tid)
	end

	def pos_revert(x, y, layer=0, map_id=$game_map.map_id)
		$game_system.revert_pos(map_id, x, y, layer)
	end

	def region_revert(rid, layer=0, map_id=$game_map.map_id)
		$game_system.revert_region(map_id, layer, rid)
	end

	def mask_revert(mask, layer=0, map_id=$game_map.map_id)
		$game_system.revert_mask(map_id, layer, mask)
	end

	def revert_all(map_id=$game_map.map_id)
		$game_system.revert_all(map_id)
	end
end

#-------------------------------------------------------------------------------
# Add-on for Overlay Maps
#-------------------------------------------------------------------------------
if $imported["TH_OverlayMaps"]
  class Game_Map
    alias :th_overlay_maps_load_new_map_data :load_new_map_data
    def load_new_map_data
      th_overlay_maps_load_new_map_data
      @overlay_maps.each {|map| map.load_new_map_data} unless self.is_a?(Game_OverlayMap)
    end
  end 
end