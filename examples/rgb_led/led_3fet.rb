require 'bitwizard'

include BitWizard

class RGBLed

	def initialize(options)
		@board = Board.detect options	

		@board.pwm_enable 1, 2, 3	
	end

	def get_rgb
		[@board[1], @board[2], @board[3]]
	end
	def set_rgb(r, g, b)
		raise ArgumentError.new "RGB have to be between 0 and 255" unless (0..255).include? r and (0..255).include? g and (0..255).include? b 

		@board[1] = r
		@board[2] = g
		@board[3] = b
	end

	def get_hsv
		to_hsv(*get_rgb)
	end
	def set_hsv(h, s, v)
		raise ArgumentError.new "Hue must be between 0 and 360" unless (0..360).include? h
		raise ArgumentError.new "Saturation and Value need to be between 0 and 1" unless (0..1).include? s and (0..1).include? v

		set_rgb(*to_rgb(h,s,v))
	end

	private

	def to_hsv(r,g,b)
		r = r / 255.0
		g = g / 255.0
		b = b / 255.0

		max = [r, g, b].max
		min = [r, g, b].min
		delta = max - min
		v = max
		 
		if (max != 0.0)
			s = delta / max
		else
			s = 0.0
		end
		 
		if (s == 0.0)
			h = 0.0
		else
			if (r == max)
				h = (g - b) / delta
			elsif (g == max)
				h = 2 + (b - r) / delta
			elsif (b == max)
				h = 4 + (r - g) / delta
			end
			 
			h *= 60.0
			if (h < 0)
				h += 360.0
			elsif (h > 360)
				h -= 360.0
			end
		end

		return *[h, s, v]
	end

	def to_rgb(h,s,v)
		h = h.to_f / 360.0
		s = s.to_f
		v = v.to_f

		hi = (h * 6).to_i
		f = h * 6 - hi
		p = v * (1 - s) * 256
		q = v * (1 - f * s) * 256
		t = v * (1 - (1 - f) * s) * 256
		v *= 256

		conv = Proc.new do
			[0,0,0] 
			if hi == 0
				[v,t,p]
			elsif hi == 1
				[q,v,p]
			elsif hi == 2
				[p,v,t]
			elsif hi == 3
				[p,q,v]
			elsif hi == 4
				[t,p,v]
			elsif hi == 5
				[v,p,q]
			end
		end

		r, g, b = *conv.call
		return *[r.to_i, g.to_i, b.to_i]
	end

end