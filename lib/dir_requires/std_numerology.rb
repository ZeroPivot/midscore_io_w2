# Standard numerology by name calculator
# VERSION: v1.0.1 - 11/19/2022
num_map = { a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7, h: 8, i: 9,
            j: 1, k: 2, l: 3, m: 4, n: 5, o: 6, p: 7, q: 8, r: 9,
            s: 1, t: 2, u: 3, v: 4, w: 5, x: 6, y: 7, z: 8 }

def digit_arity(integer_string)
  integer_string.to_s.split('').count
end

def convert_word_to_number(word, num_map)
  raise ArgumentError, 'Word cannot be nil or empty' unless !word.nil? || word != ''

  converted = word.to_s.split('').map do |i|
    num_map[i.to_sym] || 0
  end

  converted = converted.inject(0) { |result, element| result + element }

  while digit_arity(converted) > 1
    next if converted.nil?

    converted = converted.to_s.split('').inject(0) do |result, element|
      result.to_i + element.to_i
    end
    # break if (converted % 11).zero?
  end
  converted
end

# loop do
#   print 'Enter avatar name in one lowercase word: '
#   search = gets.chomp
#   puts "#{search.capitalize}'s number is: #{convert_word_to_number(search, num_map)}\n"
#   print 'Reg Numerology Number: '
# end
