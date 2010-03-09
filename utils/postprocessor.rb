#!/usr/local/bin/macruby
require 'rubygems'
require 'hotcocoa/graphics'
require 'hotcocoa/graphics/gradient'
include HotCocoa
include Graphics


def run(f)
	puts "Processing #{f}..."
	gradient = /-postprocessor-linear-gradient\((\d+), (\d+), (\w+ \w+), (\w+ \w+), (\d|\d?\.\d+), (.+?), (\d|\d?\.\d+), (rgba?\(.+?\)|.+?)\)/
	rule = /^(.+?) \{/
	rgba_background_color = /background(?:-color)?: rgba\((\d+), (\d+), (\d+), (\d\.\d)\);/
	rgba_background = /-postprocessor-rgba-bg\((rgba\(\d+, \d+, \d+, \d\.\d\))\)/
	last_rule, ie_style, png = "", "", false
	str = File.open(f).readlines 
	str.map! do |l|
		if (a = l.match gradient)
			l.gsub!(gradient, draw(a)) # pass in the matched variables from the regexp
			png = true
		elsif (a = l.match rule)
			last_rule = a[1]
		elsif (a = l.match rgba_background_color)
			col = "#" + to_hex(a[4].to_f * 255) + to_hex(a[1]) + to_hex(a[2]) + to_hex(a[3])
			ie_style << last_rule + " {\n" + "\tbackground:transparent;\n\tfilter:progid:DXImageTransform.Microsoft.Gradient(startColorstr=#{col},endColorstr=#{col}); \n\tzoom: 1; \n}"
		elsif (a = l.match rgba_background)
			l.gsub! rgba_background,  "url(data:image/png;base64,#{data_url(a)})"
		end
		l
	end
	File.open(f, 'w').write(str.join)
	puts "Internet explorer stylesheet for rgba color backrounds:\n\n", "<!--[if IE]>\n<style type=\"text/css\">\n", ie_style, "</style>\n<![endif]-->" if ie_style.length > 0
	puts "\nAlso don't forget that older IEs don't support alpha transparency. Use a script such as http://24ways.org/2007/supersleight-transparent-png-in-ie6 to support it." if png
end

def data_url(args)
	c = parse_color(args[1])
	filename = "postprocessor-tmp-image.png"
	canvas = Canvas.new :type => :image, :filename => filename, :size => [1,1]
	canvas.background c
	canvas.save
	puts "  Created data url for #{c.name} image with #{c.a} opacity."
	[File.read(filename)].pack("m*").gsub /\n/, "" #base64 encoding
end

def to_hex(i)
	s = i.to_i.to_s(16)
	if s.length == 1
		"0" + s
	else
		s
	end
end

def draw(args)
	puts args.inspect
	w, h = args[1].to_i, args[2].to_i

	s2a, s1a = args[3].split " "
	e2a, e1a = args[4].split " "
	
	s1 = pos(pos_y(s1a, h), h, args[5], s1a, e1a)
	s2 = pos(pos_x(s2a, w), w, args[5], s2a, e2a)
	e1 = pos(pos_y(s1a, h), h, args[7], s1a, e1a)
	e2 = pos(pos_x(s2a, w), w, args[7], s2a, e2a)

	#puts "sy: #{s1}, sx: #{s2}, ey: #{e1}, ex: #{e2}, cp1: #{cp1}, cp2: #{cp2}"
	c1 = parse_color(args[6]) 
	c2 = parse_color(args[8])
	filename = "images/lgradient-#{w}x#{h}-#{c1.name}-#{c2.name}.png"
	canvas = Canvas.new :type => :image, :filename => filename, :size => [w,h]
	canvas.gradient(Gradient.new(c1, c2), s2, s1, e2, e1)
	canvas.save
	puts " Wrote #{filename}."
	"url(../#{filename})"
end

def parse_color(c)
	if a = c.match(/rgba\((\d+), ?(\d+), ?(\d+), ?(\d?\.\d*)\)?/) 
		#TODO add support for otheer color schemes then rgba
		r = a[1].to_f / 255 
		g = a[2].to_f / 255
		b = a[3].to_f / 255
		a = a[4].to_f
		Color.new r, g, b, a
	end
end

# this takes the position of the start point and moved r percent down the line
def pos(v, dim, r, orig, endp)
	v + dim * r.to_f * g(orig, endp)
end

# this function finds the aim for the linear gradient
def g(a,b)
	case a
	when /top|right/
		case b
		when /top|right/
			0.0
		when /bottom|left/
			-1.0
		when /center|middle/
			-0.5
		end
	when /bottom|left/
		case b
		when /bottom|left/
			0.0
		when /top|right/
			1.0
		when /center|middle/
			0.5
		end
	end
end

def pos_y(v, h)
	case v
	when 'top'
		h
	when 'middle'
		(h/2).floor
	when 'bottom'
		0
	end
end
def pos_x(v, w)
	case v
	when 'left'
		0
	when 'center'
		(w/2).floor
	when 'right'
		w
	end
end

ARGV.each do |f|
	run f
end
File.unlink("postprocessor-tmp-image.png") rescue nil