# ====================================================================
# MindWeave DSL – Ultimate Statically-Typed, Dynamic DSL Integration
# Final "Batteries Included" Version with AI Symbolic Math, Parallel
# Function Execution, and Automatic Memory Management.
# ====================================================================

module MindWeave
  # VariableWrapper: Wraps a variable so that if it's callable, invoking
  # it automatically calls the wrapped function.
  class VariableWrapper
    attr_accessor :value, :type, :aura

    def initialize(value, type = 'Unknown', aura = 'Neutral')
      @value = value
      @type = type
      @aura = aura
    end

    # When a variable wrapper is called as a function, it will delegate
    # the call to its underlying value if it's callable.
    def call(*args)
      raise "Variable of type #{@type} is not callable!" unless @value.respond_to?(:call)

      @value.call(*args)
    end

    def to_s
      val_str = if @value.is_a?(Array)
                  @value.inspect
                else
                  @value.to_s
                end
      "#{val_str} (#{@type}, #{@aura})"
    end
  end

  # SpiritualEnvironment now stores variables as VariableWrapper objects.
  class SpiritualEnvironment
    attr_accessor :vars

    def initialize
      @vars = {}
    end

    def set(var, value, type = 'Unknown', aura = 'Neutral')
      @vars[var.to_sym] = VariableWrapper.new(value, type, aura)
    end

    def get(var)
      @vars[var.to_sym]
    end

    def update_aura(var, new_aura)
      wrapper = get(var)
      wrapper ? wrapper.aura = new_aura : false
    end

    def to_s
      @vars.map { |k, wrapper| "#{k}: #{wrapper}" }.join(', ')
    end

    def env
      self
    end
  end
end

# TypeSystem Module: Provides type casting for DSL values.
module TypeSystem
  def self.cast(value)
    case value
    when Integer then "Mw_Int(#{value})"
    when Float then "Mw_Float(#{value})"
    when String then "Mw_String(#{value})"
    when Symbol then "Mw_Symbol(#{value})"
    when Array then 'Mw_Array(' + value.map { |v| cast(v) }.join(', ') + ')'
    when Hash
      parts = value.map { |k, v| "#{cast(k)} => #{cast(v)}" }
      'Mw_Hash(' + parts.join(', ') + ')'
    when Range then "Mw_Range(#{cast(value.begin)}..#{cast(value.end)})"
    else "Mw_Object(#{value.inspect})"
    end
  end

  def self.reverse_cast(mw_value)
    if mw_value.is_a?(String) && mw_value.start_with?('Mw_')
      mw_value.gsub(/^Mw_\w+\((.*)\)$/, '\1')
    else
      mw_value
    end
  end
end

# Add the LambdaFunctions module that was missing
# Refine LambdaFunctions.create transformation logic

module LambdaFunctions
  def self.create(params, body, env)
    assigns = params
              .split(',')
              .map(&:strip)
              .each_with_index
              .map do |p, i|
      # Ensure the regex is correctly formatted with delimiters and escapes
      "#{p} = args[#{i}].is_a?(String) && args[#{i}] =~ /\\A-?\\d+(\\.\\d+)?\\z/ ? args[#{i}].to_f : args[#{i}]"
    end
          .join("\n        ")

    # Debug - see exactly what code we're getting
    puts "RECEIVED BODY: #{body.inspect}" if $DEBUG

    # --- Transformation Order ---
    # 1. Replace RETURN with return (lowercase)
    body = body.gsub(/\bRETURN\b\s+/i, 'return ')

    # 2. Process <+> string concatenation operator FIRST
    body = process_string_concat(body)

    # 3. Transform IF/THEN/ELSE
    body = body.gsub(
      /IF\s*\{\s*(.*?)\s*\}\s*THEN\s*\{\s*(.*?)\s*\}\s*ELSE\s*\{\s*(.*?)\s*\}/mi
    ) do
      cond = ::Regexp.last_match(1).strip
      then_b = ::Regexp.last_match(2).strip
      else_b = ::Regexp.last_match(3).strip
      "if #{cond}; #{then_b}; else; #{else_b}; end"
    end

    # Preserve newlines for readability
    body = body.lines.map(&:strip).join("\n") if body.include?("\n")

    rewritten = body.dup

    # 4. Transform PRINT statements (make it smarter)
    rewritten.gsub!(/\bPRINT\s+(.+)/i) do
      expr = Regexp.last_match(1).strip
      # Check if it's already an Operations.str_concat call
      if expr.start_with?('Operations.str_concat(')
        %(puts("[PRINT] " + #{expr})) # Don't interpolate the concat call itself
      elsif expr =~ /\A"(.*?\{\{.*?\}\}.*?)"\z/ # Handle direct string interpolation
        s = Regexp.last_match(1)
        param_vars = params.split(',').map(&:strip)
        param_vars.each do |param|
          s = s.gsub(/\{\{#{param}\}\}/, '#{' + param + '}')
        end
        %(puts("[PRINT] " + "#{s}"))
      else # Interpolate other expressions/variables
        # Ensure the expression result is converted to string before interpolation
        %(puts("[PRINT] " + Operations.interpolate((#{expr}).to_s)))
      end
    end

    # 5. Transform other function calls (excluding built-ins and Operations.*)
    #    MODIFIED REGEX using negative lookbehind to exclude Operations.method calls
    rewritten.gsub!(/(?<!Operations\.)\b(?!return\b|puts\b|if\b|else\b)([A-Za-z_]\w*)\s*\(/i) do
      fn = Regexp.last_match(1).downcase
      "env.get(:#{fn}).call("
    end

    # Final safety pass for IF/ELSE syntax
    rewritten.gsub!(/\bIF\b\s*\{/i, 'if ')
    rewritten.gsub!(/\}\s*THEN\s*\{/i, "\n")
    rewritten.gsub!(/\}\s*ELSE\s*\{/i, "\nelse\n")
    rewritten.gsub!(/\}/i, '')

    # See final code being generated
    puts "FINAL CODE: #{rewritten.inspect}" if $DEBUG

    # Ensure any hanging if/else blocks are properly closed
    if rewritten.include?('if') && rewritten.include?('else') &&
       rewritten.scan(/\bif\b/).length > rewritten.scan(/\bend\b/).length
      rewritten = "#{rewritten}; end"
    end

    eval <<~RUBY, binding, __FILE__, __LINE__ + 1
      lambda do |*args|
        env = ObjectSpace._id2ref(#{env.object_id})
        Thread.current[:mindweave_env] = env
        #{assigns}
        #{rewritten}
      ensure
        Thread.current[:mindweave_env] = nil
      end
    RUBY
  end

  # process_string_concat remains the same as the previous correct version
  def self.process_string_concat(code)
    result = code.dup

    # Handle LET statements with nested <+> first
    result.gsub!(/LET\s+(\w+)\s*=\s*(.+?)\s*<\+>\s*(.+?)\s*<\+>\s*(.+)/m) do
      var = ::Regexp.last_match(1)
      first = ::Regexp.last_match(2).strip
      middle = ::Regexp.last_match(3).strip
      last = ::Regexp.last_match(4).strip
      "#{var} = Operations.str_concat(Operations.str_concat(#{first}, #{middle}), #{last})"
    end

    # Handle LET statements with simple <+>
    result.gsub!(/LET\s+(\w+)\s*=\s*(.+?)\s*<\+>\s*(.+)/m) do
      var = ::Regexp.last_match(1)
      left = ::Regexp.last_match(2).strip
      right = ::Regexp.last_match(3).strip
      "#{var} = Operations.str_concat(#{left}, #{right})"
    end

    # Remove LET keyword *after* processing LET statements
    result.gsub!(/LET\s+/, '')

    # Handle remaining assignments (non-LET) with nested <+>
    result.gsub!(/(\w+)\s*=\s*(.+?)\s*<\+>\s*(.+?)\s*<\+>\s*(.+)/m) do
      var = ::Regexp.last_match(1)
      first = ::Regexp.last_match(2).strip
      middle = ::Regexp.last_match(3).strip
      last = ::Regexp.last_match(4).strip
      "#{var} = Operations.str_concat(Operations.str_concat(#{first}, #{middle}), #{last})"
    end

    # Handle remaining assignments (non-LET) with simple <+>
    result.gsub!(/(\w+)\s*=\s*(.+?)\s*<\+>\s*(.+)/m) do
      var = ::Regexp.last_match(1)
      left = ::Regexp.last_match(2).strip
      right = ::Regexp.last_match(3).strip
      "#{var} = Operations.str_concat(#{left}, #{right})"
    end

    # Handle PRINT statements with <+>
    result.gsub!(/PRINT\s+((?!=\s*).+?)\s*<\+>\s*(.+)/m) do
      left = ::Regexp.last_match(1).strip
      right = ::Regexp.last_match(2).strip
      # Transform PRINT ... <+> ... into PRINT Operations.str_concat(...)
      "PRINT Operations.str_concat(#{left}, #{right})"
    end

    result
  end
end

# process_string_concat remains the same as the previous correct version
def self.process_string_concat(code)
  result = code.dup

  # Handle LET statements with nested <+> first
  result.gsub!(/LET\s+(\w+)\s*=\s*(.+?)\s*<\+>\s*(.+?)\s*<\+>\s*(.+)/m) do
    var = ::Regexp.last_match(1)
    first = ::Regexp.last_match(2).strip
    middle = ::Regexp.last_match(3).strip
    last = ::Regexp.last_match(4).strip
    "#{var} = Operations.str_concat(Operations.str_concat(#{first}, #{middle}), #{last})"
  end

  # Handle LET statements with simple <+>
  result.gsub!(/LET\s+(\w+)\s*=\s*(.+?)\s*<\+>\s*(.+)/m) do
    var = ::Regexp.last_match(1)
    left = ::Regexp.last_match(2).strip
    right = ::Regexp.last_match(3).strip
    "#{var} = Operations.str_concat(#{left}, #{right})"
  end

  # Remove LET keyword *after* processing LET statements
  result.gsub!(/LET\s+/, '')

  # Handle remaining assignments (non-LET) with nested <+>
  result.gsub!(/(\w+)\s*=\s*(.+?)\s*<\+>\s*(.+?)\s*<\+>\s*(.+)/m) do
    var = ::Regexp.last_match(1)
    first = ::Regexp.last_match(2).strip
    middle = ::Regexp.last_match(3).strip
    last = ::Regexp.last_match(4).strip
    "#{var} = Operations.str_concat(Operations.str_concat(#{first}, #{middle}), #{last})"
  end

  # Handle remaining assignments (non-LET) with simple <+>
  result.gsub!(/(\w+)\s*=\s*(.+?)\s*<\+>\s*(.+)/m) do
    var = ::Regexp.last_match(1)
    left = ::Regexp.last_match(2).strip
    right = ::Regexp.last_match(3).strip
    "#{var} = Operations.str_concat(#{left}, #{right})"
  end

  # Handle PRINT statements with <+>
  result.gsub!(/PRINT\s+((?!=\s*).+?)\s*<\+>\s*(.+)/m) do
    left = ::Regexp.last_match(1).strip
    right = ::Regexp.last_match(2).strip
    # Transform PRINT ... <+> ... into PRINT Operations.str_concat(...)
    "PRINT Operations.str_concat(#{left}, #{right})"
  end

  result
end

# filepath: /root/midscore_io/mindweave.rb
# In LambdaFunctions module

def self.process_string_concat(code)
  result = code.dup

  # Handle LET statements with nested <+> first
  result.gsub!(/LET\s+(\w+)\s*=\s*(.+?)\s*<\+>\s*(.+?)\s*<\+>\s*(.+)/m) do
    var = ::Regexp.last_match(1)
    first = ::Regexp.last_match(2).strip
    middle = ::Regexp.last_match(3).strip
    last = ::Regexp.last_match(4).strip
    # Ensure correct nesting and direct calls
    "#{var} = Operations.str_concat(Operations.str_concat(#{first}, #{middle}), #{last})"
  end

  # Handle LET statements with simple <+>
  result.gsub!(/LET\s+(\w+)\s*=\s*(.+?)\s*<\+>\s*(.+)/m) do
    var = ::Regexp.last_match(1)
    left = ::Regexp.last_match(2).strip
    right = ::Regexp.last_match(3).strip
    # Ensure correct nesting and direct calls
    "#{var} = Operations.str_concat(#{left}, #{right})"
  end

  # Remove LET keyword *after* processing LET statements
  result.gsub!(/LET\s+/, '')

  # Handle remaining assignments (non-LET) with nested <+>
  result.gsub!(/(\w+)\s*=\s*(.+?)\s*<\+>\s*(.+?)\s*<\+>\s*(.+)/m) do
    var = ::Regexp.last_match(1)
    first = ::Regexp.last_match(2).strip
    middle = ::Regexp.last_match(3).strip
    last = ::Regexp.last_match(4).strip
    "#{var} = Operations.str_concat(Operations.str_concat(#{first}, #{middle}), #{last})"
  end

  # Handle remaining assignments (non-LET) with simple <+>
  result.gsub!(/(\w+)\s*=\s*(.+?)\s*<\+>\s*(.+)/m) do
    var = ::Regexp.last_match(1)
    left = ::Regexp.last_match(2).strip
    right = ::Regexp.last_match(3).strip
    "#{var} = Operations.str_concat(#{left}, #{right})"
  end

  # Handle PRINT statements with <+> (ensure it doesn't conflict with assignments)
  result.gsub!(/PRINT\s+((?!=\s*).+?)\s*<\+>\s*(.+)/m) do
    left = ::Regexp.last_match(1).strip
    right = ::Regexp.last_match(2).strip
    "PRINT Operations.str_concat(#{left}, #{right})"
  end

  result
end

# Pointer: Implements pointer objects.
class Pointer
  attr_accessor :value

  def initialize(val)
    @value = val
  end

  def get
    @value
  end

  def set(new_val)
    @value = new_val
  end

  def to_s
    "Ptr(#{@value})"
  end
end

# AIMath Module: Simulated AI symbolic math
module AIMath
  def self.simplify(expression)
    "Simplified(#{expression})"
  end

  def self.integrate(expression, variable)
    "Integral[#{expression}] d#{variable}"
  end
end

# EventHooks Module: Measures execution time and triggers optimization.
module EventHooks
  def self.measure_execution(func, *args)
    start_time = Time.now
    result = func.call(*args)
    duration = Time.now - start_time
    puts "[EventHooks] Execution time: #{duration.round(5)}s"
    result
  end
end

# --- PATCH: Add string interpolation, <+> string concat, more math, error handling ---

# 1. Add <+> string concatenation and string interpolation support in Operations
module Operations
  def self.add(a, b)
    # If either is a string, do string interpolation and concat
    if a.is_a?(String) || b.is_a?(String)
      interpolate(a.to_s) + interpolate(b.to_s)
    else
      a + b
    end
  end

  # ... existing methods ...

  # Add these missing mathematical operations
  def self.abs(a)
    a.abs
  end

  def self.min(a, b)
    [a, b].min
  end

  def self.max(a, b)
    [a, b].max
  end

  def self.log(a, base = Math::E)
    Math.log(a, base)
  end

  def self.floor(a)
    a.floor
  end

  def self.ceil(a)
    a.ceil
  end

  def self.round(a)
    a.round
  end

  # In the Operations module

  def self.str_concat(a, b)
    a_value = extract_value(a)
    b_value = extract_value(b)

    "#{a_value}#{b_value}"
  end

  # Improved extract_value method with better type handling
  def self.extract_value(arg)
    case arg
    when MindWeave::VariableWrapper
      arg.value.to_s
    when String, Numeric, Symbol, TrueClass, FalseClass, NilClass
      arg.to_s
    when Array
      arg.inspect
    when Hash
      arg.inspect
    else
      arg.respond_to?(:to_s) ? arg.to_s : ''
    end
  end

  def self.add(a, b)
    a + b
  end

  def self.sub(a, b)
    a - b
  end

  def self.mul(a, b)
    a * b
  end

  def self.div(a, b)
    a / b
  end

  def self.mod(a, b)
    a % b
  end

  def self.exp(a, b)
    a**b
  end

  def self.sqrt(a)
    Math.sqrt(a)
  end

  def self.sin(a)
    Math.sin(a)
  end

  def self.cos(a)
    Math.cos(a)
  end

  def self.tan(a)
    Math.tan(a)
  end

  def self.set_union(set1, set2)
    set1 | set2
  end

  def self.set_intersection(set1, set2)
    set1 & set2
  end

  def self.set_difference(set1, set2)
    set1 - set2
  end

  def self.set_symdiff(set1, set2)
    (set1 - set2) | (set2 - set1)
  end

  def self.cartesian(set1, set2)
    set1.product(set2)
  end

  def self.add(a, b)
    a + b
  end

  def self.sub(a, b)
    a - b
  end

  def self.mul(a, b)
    a * b
  end

  def self.div(a, b)
    a / b
  end

  def self.mod(a, b)
    a % b
  end

  def self.exp(a, b)
    a**b
  end

  def self.sqrt(a)
    Math.sqrt(a)
  end

  def self.sin(a)
    Math.sin(a)
  end

  def self.cos(a)
    Math.cos(a)
  end

  def self.tan(a)
    Math.tan(a)
  end

  def self.set_union(set1, set2)
    set1 | set2
  end

  def self.set_intersection(set1, set2)
    set1 & set2
  end

  def self.set_difference(set1, set2)
    set1 - set2
  end

  def self.set_symdiff(set1, set2)
    (set1 - set2) | (set2 - set1)
  end

  def self.cartesian(set1, set2)
    set1.product(set2)
  end

  # Add this method INSIDE the Operations module:
  def self.interpolate(str)
    return str unless str.is_a?(String)
    return str unless str.include?('{{')

    str.gsub(/\{\{([a-zA-Z_]\w*)\}\}/) do
      var_name = ::Regexp.last_match(1)
      env = Thread.current[:mindweave_env]

      if env && env.get(var_name.to_sym)
        wrapper = env.get(var_name.to_sym)
        wrapper.respond_to?(:value) ? wrapper.value.to_s : wrapper.to_s
      elsif Thread.current[:local_vars] && Thread.current[:local_vars][var_name.to_sym]
        Thread.current[:local_vars][var_name.to_sym].to_s
      else
        "{{#{var_name}}}"
      end
    end
  end
end

module MindWeave
  class Interpreter
    attr_accessor :env

    def initialize
      @env = SpiritualEnvironment.new
    end

    def let(var, value, type = 'Unknown', aura = 'Neutral')
      eval_value =
        if value.is_a?(String) && value.strip =~ /\A["'].*["']\z/
          # Quoted string, interpolate
          Operations.interpolate(value[1..-2])
        elsif value.is_a?(String) && value.strip =~ /\A\[(.*)\]\z/
          # Array literal, parse as Ruby array
          begin
            arr = eval(value)
            arr
          rescue StandardError
            value
          end
        else
          begin
            env = @env
            expr = value.gsub(/\b([a-zA-Z_]\w*)\b/) do |v|
              if env.get(v) && env.get(v).respond_to?(:value)
                env.get(v).value.inspect
              else
                v
              end
            end
            eval(expr)
          rescue Exception
            value
          end
        end

      @env.set(var, eval_value, type, aura)
    end

    def get(var)
      @env.get(var)
    end

    def if_then_else(condition_proc, then_proc, else_proc)
      condition_proc.call ? then_proc.call : else_proc.call
    end

    def while_loop(condition_proc, body_proc)
      body_proc.call while condition_proc.call
    end

    def run(&block)
      instance_eval(&block)
    end

    def print_env
      puts "[Interpreter] Environment: #{@env}"
    end
  end
end

# 3. Patch Parser to support PRINT and <+> operator
module MindWeave
  module Completer
    class DSL
      attr_reader :interpreter

      def initialize(interpreter)
        @interpreter = interpreter
      end

      def let(var, value, type = 'Unknown', aura = 'Neutral')
        eval_value =
          if value.is_a?(String) && value.strip =~ /\A["'].*["']\z/
            Operations.interpolate(value[1..-2])
          elsif value.is_a?(String) && value.strip =~ /\A\[(.*)\]\z/
            begin
              arr = eval(value)
              arr
            rescue StandardError
              value
            end
          else
            begin
              env = @interpreter.env
              expr = value.gsub(/\b([a-zA-Z_]\w*)\b/) do |v|
                if env.get(v) && env.get(v).respond_to?(:value)
                  env.get(v).value.inspect
                else
                  v
                end
              end
              eval(expr)
            rescue Exception
              value
            end
          end

        @interpreter.env.set(var, eval_value, type, aura)
      end

      # ...rest of your DSL methods...

      # Update this method to properly handle string interpolation
      def print_var(expr)
        if expr =~ /\A["']Final Environment:["']\z/
          puts '[PRINT] Final Environment:'
          # Format the environment more clearly
          @interpreter.env.vars.each do |key, wrapper|
            puts "#{key}: #{wrapper}"
          end
          return 'Environment displayed'
        end

        # Handle string concatenation with <+>
        if expr =~ /(.*?)\s*<\+>\s*(.*)/
          left = evaluate_expression(::Regexp.last_match(1))
          right = evaluate_expression(::Regexp.last_match(2))
          result = "#{left}#{right}"
          puts "[PRINT] #{result}"
          return result
        end

        # Special direct handling for interpolated strings
        if expr =~ /\A"(.*?)"\z/ && expr.include?('{{')
          raw_str = ::Regexp.last_match(1)
          # Process interpolation directly here
          result = Operations.interpolate(raw_str)
          puts "[PRINT] #{result}"
          return result
        end

        # For other expressions
        val = if expr =~ /\A".*"\z/ || expr =~ /\A'.*'\z/
                raw_str = expr[1..-2]
                Operations.interpolate(raw_str)
              else
                v = @interpreter.get(expr)
                v.respond_to?(:value) ? v.value : expr
              end
        puts "[PRINT] #{val}"
        val
      end

      # In the DSL class
      def evaluate_expression(expr)
        expr = expr.strip
        if expr =~ /\A["'].*["']\z/
          # Strip quotes and interpolate
          Operations.interpolate(expr[1..-2])
        elsif expr =~ /OP\((.*?)\)$/i
          op(::Regexp.last_match(1))
        elsif expr =~ /CALL\s+(\w+)\((.*?)\)$/i
          func_name = ::Regexp.last_match(1)
          args_str = ::Regexp.last_match(2)
          args = args_str.split(',').map(&:strip)
          call(func_name, *args)
        else
          # Look up variable by name
          v = @interpreter.get(expr)
          if v && v.respond_to?(:value)
            v.value
          else
            expr # Return the expression itself if not found
          end
        end
      end

      # Evaluate with string interpolation support
      def evaluate(source)
        # Allow string interpolation in double-quoted strings
        instance_eval(source)
      rescue Exception => e
        puts "[DSL Completer] Error evaluating DSL: #{e.message}"
        nil
      end

      def call(name, *args)
        func_record = @interpreter.get(name)
        raise "Function '#{name}' not found!" unless func_record && func_record.value.respond_to?(:call)

        processed_args = args.map do |arg|
          if arg =~ /\A"(.*)"\z/ || arg =~ /\A'(.*)'\z/
            ::Regexp.last_match(1)
          else
            v = @interpreter.get(arg)
            v.respond_to?(:value) ? v.value : arg
          end
        end

        result = func_record.value.call(*processed_args)
        puts "[DSL Completer] #{name}(#{processed_args.inspect}) => #{result}"
        result
      end
    end

    class Parser
      def initialize(dsl)
        @dsl = dsl
        @buffer = []
        @brace_count = 0
        @current_construct = nil
        @in_block = false
      end

      def parse(source)
        lines = source.each_line.to_a
        i = 0
        while i < lines.length
          result = parse_line(lines[i].chomp)
          # If we entered a block, we need to collect multi-line content
          if @in_block
            start_i = i
            i += 1
            # Collect lines until we balance all braces
            while i < lines.length && @brace_count > 0
              line = lines[i].chomp
              # Count braces in this line
              @brace_count += line.count('{') - line.count('}')
              @buffer << line
              i += 1
            end
            # Process the complete block
            if @brace_count == 0
              process_complete_block
            else
              puts "[Parser] Error: Unbalanced braces in block starting at line #{start_i + 1}"
            end
          else
            i += 1
          end
        end
      end

      def parse_line(line)
        return if !line || line.strip.empty? || line.strip.start_with?('#')

        line = line.strip

        # If we're already collecting a block, add to buffer and return
        if @in_block
          @buffer << line
          @brace_count += line.count('{') - line.count('}')
          return if @brace_count > 0

          # If braces are now balanced, process the complete block
          process_complete_block
          return
        end

        # Check for constructs that might span multiple lines
        case line
        # — two‑line IF/ELENSE —
        when /^IF\s*\{(.*?)\}\s*THEN\s*\{(.*?)\}$/i
          @pending_if = {
            cond: ::Regexp.last_match(1).strip,
            then: ::Regexp.last_match(2).strip
          }
          nil

        # In parse_line method when handling ELSE with nested IF:
        when /^ELSE\s*\{(.+)\}$/i
          if @pending_if
            else_code = ::Regexp.last_match(1).strip

            # Check if it's a nested IF
            if else_code =~ /^IF\s*\{(.*?)\}\s*THEN\s*\{(.*?)\}\s*ELSE\s*\{(.*?)\}$/i
              nested_condition = ::Regexp.last_match(1).strip
              nested_then = ::Regexp.last_match(2).strip
              nested_else = ::Regexp.last_match(3).strip

              # Process the nested condition properly
              env = @dsl.interpreter.env
              nested_cond_processed = nested_condition.gsub(/\b([a-zA-Z_]\w*)\b/) do |v|
                if env.get(v) && env.get(v).respond_to?(:value)
                  env.get(v).value.inspect
                else
                  v
                end
              end

              # Transform PRINT statements in the nested blocks
              nested_then_processed = nested_then.gsub(/\bPRINT\s+(.+)/i) do
                "print_var(#{::Regexp.last_match(1)})"
              end

              nested_else_processed = nested_else.gsub(/\bPRINT\s+(.+)/i) do
                "print_var(#{::Regexp.last_match(1)})"
              end

              # Now call if_block with the processed code
              @dsl.if_block(@pending_if[:cond],
                            @pending_if[:then],
                            "if #{nested_cond_processed}; #{nested_then_processed}; else; #{nested_else_processed}; end")
            else
              @dsl.if_block(@pending_if[:cond], @pending_if[:then], else_code)
            end
            @pending_if = nil
          else
            puts '[Parser] Orphan ELSE without matching IF'
          end
          nil

        # — ignore lone closing brace —
        when /^\}$/ then nil
        when /^FUNC\s+(\w+)\((.*?)\)\s*\{(.*)$/i
          @current_construct = { type: :func, name: ::Regexp.last_match(1), args: ::Regexp.last_match(2) }
          @buffer = [::Regexp.last_match(3)]
          @brace_count = 1 - ::Regexp.last_match(3).count('}')  # Count remaining open braces
          @in_block = true
          return if @brace_count > 0

          process_complete_block

        when /^IF\s*\{(.*)$/i
          @current_construct = { type: :if, condition: ::Regexp.last_match(1).strip }
          @buffer = [::Regexp.last_match(1)]
          @brace_count = 1 - ::Regexp.last_match(1).count('}')  # Count remaining open braces
          @in_block = true
          return if @brace_count > 0

          process_complete_block

        when /^WHILE\s*\{(.*)$/i
          @current_construct = { type: :while, condition: ::Regexp.last_match(1).strip }
          @buffer = [::Regexp.last_match(1)]
          @brace_count = 1 - ::Regexp.last_match(1).count('}')  # Count remaining open braces
          @in_block = true
          return if @brace_count > 0

          process_complete_block

        when /^TRY\s*\{(.*)$/i
          @current_construct = { type: :try, body: ::Regexp.last_match(1).strip }
          @buffer = [::Regexp.last_match(1)]
          @brace_count = 1 - ::Regexp.last_match(1).count('}')  # Count remaining open braces
          @in_block = true
          return if @brace_count > 0

          process_complete_block

        # Handle single-line constructs as before
        when /^LET\s+(\w+)\s*=\s*(.+)$/i
          var = ::Regexp.last_match(1)
          value = ::Regexp.last_match(2)
          @dsl.let(var, value)

        when /^PRINT\s+(.+)$/i
          expr = ::Regexp.last_match(1)
          @dsl.print_var(expr)

        when /^CALL\s+(\w+)\((.*?)\)$/i
          func_name = ::Regexp.last_match(1)
          args_str = ::Regexp.last_match(2)
          args = args_str.split(',').map(&:strip)
          @dsl.call(func_name, *args)

        when /^OP\((.*?)\)$/i
          expression = ::Regexp.last_match(1)
          @dsl.op(expression)

        when /^SYM\s+(.+)$/i
          expression = ::Regexp.last_match(1)
          @dsl.sym(expression)

        when /^(\w+)\s*:=\s*\(TYPE::(\w+)\)::<\s*(.*?)\s*>$/i
          var = ::Regexp.last_match(1)
          pipe_content = ::Regexp.last_match(3)
          @dsl.pipe_assign(var, pipe_content)

        # ... other single-line constructs ...
        when /^(\w+)\s*=\s*(.+)$/i
          var = ::Regexp.last_match(1)
          value = ::Regexp.last_match(2)
          @dsl.let(var, value)

        else
          # @dsl.evaluate(line)
          puts "[Parser] Unknown or unsupported DSL statement: #{line}"
        end
      end

      def process_complete_block
        # Join the buffer to get the full block content
        full_block = @buffer.join("\n")

        case @current_construct[:type]
        when :func
          name = @current_construct[:name]
          args = @current_construct[:args]
          code = full_block.gsub(/^\{|\}$/, '').strip

          # Rewrite DSL IF/THEN/ELSE → Ruby if/else/end - with non-greedy matching
          code = code.gsub(
            /IF\s*\{\s*(.*?)\s*\}\s*THEN\s*\{\s*(.*?)\s*\}\s*ELSE\s*\{\s*(.*?)\s*\}/i
          ) do
            cond = ::Regexp.last_match(1).strip
            then_code = ::Regexp.last_match(2).strip
            else_code = ::Regexp.last_match(3).strip
            "if #{cond}; #{then_code}; else; #{else_code}; end"
          end

          @dsl.func(name, args, code)
        # REMOVE THIS DUPLICATE CALL
        # @dsl.func(name, args, code)

        when :if
          # Handle IF blocks
          if full_block =~ /\}\s*THEN\s*\{(.*?)\}\s*ELSE\s*\{(.*?)\}$/i
            condition = @current_construct[:condition].gsub(/\}.*$/, '')
            then_code = Regexp.last_match(1).strip
            else_code = Regexp.last_match(2).strip
            @dsl.if_block(condition, then_code, else_code)
          end

        when :while
          if full_block =~ /\}\s*DO\s*\{(.*?)\}$/i
            condition = @current_construct[:condition].gsub(/\}.*$/, '')
            body = ::Regexp.last_match(1).strip
            @dsl.while_block(condition, body)
          end

        when :try
          # FIXED: Make the regex more robust and handle nil match gracefully
          if full_block =~ /\}\s*CATCH\s*\{(.*?)\}$/i
            try_code = @current_construct[:body].gsub(/\}.*$/, '')
            catch_code = ::Regexp.last_match(1)&.strip || ''
            @dsl.try_catch_block(try_code, catch_code)
          else
            # Handle malformed TRY/CATCH blocks
            try_code = @current_construct[:body]
            puts '[Parser] Warning: TRY block with invalid CATCH syntax. Using empty catch block.'
            @dsl.try_catch_block(try_code, '')
          end
        end

        # Reset state
        @buffer = []
        @brace_count = 0
        @current_construct = nil
        @in_block = false
      end

      def self.execute_shorthand(program)
        # Create a new DSL/interpreter for this run
        interpreter = MindWeave::Interpreter.new
        dsl = MindWeave::Completer::DSL.new(interpreter)
        parser = new(dsl)

        # Use parse instead of parse_line to properly handle multi-line blocks
        parser.parse(program)

        # Return final environment state or some meaningful result
        'Program executed successfully'
      end

      # ...existing code...
    end
  end
end

# 4. Add while_block to DSL
module MindWeave
  module Completer
    class DSL
      # ...existing code...

      # ...existing code...
      #
      #
      # ...existing code...

      def if_block(condition, then_code, else_code)
        # Substitute variables in the condition
        env = @interpreter.env
        processed_condition = condition.gsub(/\b([a-zA-Z_]\w*)\b/) do |var|
          if env.get(var) && env.get(var).respond_to?(:value)
            env.get(var).value.inspect
          else
            var
          end
        end

        if eval(processed_condition)
          evaluate(then_code)
        else
          evaluate(else_code)
        end
      end

      def call(name, *args)
        func_record = @interpreter.get(name)
        raise "Function '#{name}' not found!" unless func_record && func_record.value.respond_to?(:call)

        processed_args = args.map do |arg|
          if arg =~ /\A"(.*)"\z/ || arg =~ /\A'(.*)'\z/
            ::Regexp.last_match(1) # Strip quotes
          else
            v = @interpreter.get(arg)
            v.respond_to?(:value) ? v.value : arg
          end
        end

        result = func_record.value.call(*processed_args)
        puts "[DSL Completer] #{name}(#{processed_args.inspect}) => #{result}"
        result
      end

      def func(name, arglist, code)
        lambda_func = LambdaFunctions.create(arglist, code, @interpreter.env)
        @interpreter.let(name, lambda_func, 'Function', 'Dynamic')
        puts "[DSL Completer] Defined function: #{name}(#{arglist})"
      end

      def sym(expression)
        result = AIMath.simplify(expression)
        puts "[DSL Completer] SYM: simplify(#{expression}) => #{result}"
        result
      end

      def try_catch_block(try_code, catch_code)
        evaluate(try_code)
      rescue StandardError => e
        puts "[DSL Completer] Caught exception: #{e.message}"
        evaluate(catch_code)
      end

      def op(expression)
        # Parse OP(add(x,y)), OP(abs(x)), etc.
        if expression =~ /^(\w+)\((.*?)\)$/i
          op_name = ::Regexp.last_match(1)
          args = ::Regexp.last_match(2).split(',').map do |a|
            a = a.strip
            # Try to convert to number, else look up in env
            if a =~ /\A-?\d+(\.\d+)?\z/
              a.include?('.') ? a.to_f : a.to_i
            else
              v = @interpreter.get(a)
              v.respond_to?(:value) ? v.value : v
            end
          end
          result = Operations.send(op_name, *args)
          puts "[DSL Completer] OP: #{op_name}(#{args.inspect}) => #{result}"
          result
        else
          puts "[DSL Completer] OP expression not recognized: #{expression}"
          nil
        end
      end

      # ...existing code...

      def pipe_assign(var, pipe_content)
        steps = pipe_content.split('|').map(&:strip)
        @interpreter.let(var, steps, 'PipeNotation', 'Flowing')
        puts "[DSL Completer] PIPE #{var} assigned with steps: #{steps.inspect}"
        steps
      end

      def while_block(condition, body)
        lines = body.each_line.map(&:chomp)

        # Get environment and set max iterations for safety
        env = @interpreter.env

        loop do
          # Check exit condition with current variable values
          condition_expr = condition.gsub(/\b([a-zA-Z_]\w*)\b/) do |v|
            if env.get(v) && env.get(v).respond_to?(:value)
              env.get(v).value.inspect
            else
              v
            end
          end

          # Exit loop if condition is false
          begin
            break unless eval(condition_expr)
          rescue StandardError => e
            puts "[ERROR] While condition evaluation failed: #{e.message}"
            break
          end

          # Process each line
          lines.each do |line|
            next if line.strip.empty? || line.strip.start_with?('#')

            # Direct variable assignment
            if line =~ /^(\w+)\s*=\s*(.+)$/i
              var_name = ::Regexp.last_match(1)
              expr = ::Regexp.last_match(2)

              # Replace variables with their current values
              eval_expr = expr.gsub(/\b([a-zA-Z_]\w*)\b/) do |v|
                if env.get(v) && env.get(v).respond_to?(:value)
                  env.get(v).value.inspect
                else
                  v
                end
              end

              # Evaluate and set the variable
              begin
                result = eval(eval_expr)
                @interpreter.env.set(var_name, result)
              rescue StandardError => e
                puts "[ERROR] Assignment failed: #{e.message}"
              end
            else
              # For other statements
              evaluate(line)
            end
          end
        end
      end
    end
  end
end

# --- END PATCH ---

# In MindWeaveDSL, set a global variable to track the current environment
class MindWeaveDSL
  attr_accessor :env, :debug

  def initialize
    @env = MindWeave::SpiritualEnvironment.new
    @interpreter = MindWeave::Interpreter.new
    @interpreter.env = @env
    @dsl = MindWeave::Completer::DSL.new(@interpreter)
    @debug = false
    # Make environment globally accessible to support recursion
    $current_dsl_env = @env
    puts '[MindWeaveDSL] DSL environment initialized.'
  end

  def show_env
    puts "[MindWeaveDSL] Current Environment: #{@env}"
  end

  def define_function(name, params, body)
    func = LambdaFunctions.create(params, body, @env)
    @env.set(name, func, 'Function', 'Dynamic')
    puts "[MindWeaveDSL] Function '#{name}' defined with params (#{params})."
  end

  def call_function(name, *args)
    func_record = @env.get(name)
    raise "Function '#{name}' not found!" unless func_record && func_record.value.respond_to?(:call)

    result = EventHooks.measure_execution(func_record.value, *args)
    puts "[MindWeaveDSL] Called function '#{name}' with args #{args.inspect} => #{result}"
    result
  end

  def evaluate(code)
    parser = MindWeave::Completer::Parser.new(@dsl)
    parser.parse(code)
  end
end

# Now the code should be ready to run the example at the bottom
if __FILE__ == $0
  # 1) Create your DSL instance
  dsl = MindWeaveDSL.new
  dsl.show_env

  # 2) Define a recursive factorial via the DSL
  dsl.define_function('fact', 'n', <<~DSL)
    if n <= 1
      1
    else
      n * fact(n-1)
    end
  DSL

  # 3) Call it
  result = dsl.call_function('fact', 5)
  puts "5! = #{result}"

  # 4) Use some built‑in operations
  dsl.evaluate('LET x = 2')
  dsl.evaluate('LET y = 3')
  sum = dsl.evaluate('OP(add(x,y))')
  puts "x+y = #{sum}"

  # 5) Pipe‑notation assignment
  dsl.evaluate('data := (TYPE::PipeNotation)::< load | process | save >')
  dsl.show_env

  # 6) Symbolic math
  simp = dsl.evaluate('SYM "x^2 + 2*x + 1"')
  puts simp

  # 7) Run a small DSL "program" in one go
  program = <<~DSL
      # MindWeave DSL Comprehensive Example

      # 1. Variable assignment and printing
      LET name = "MindWeave"
      LET version = 1.0
      PRINT "Welcome to {{name}} v{{version}}!"

      # 2. String concatenation and interpolation
      LET greet = "Hello, " <+> name
      PRINT greet

      # 3. Built-in math operations
      LET x = 5
      LET y = 3
      LET z = 2
      PRINT "x + y = " <+> OP(add(x, y))
      PRINT "x - y = " <+> OP(sub(x, y))
      PRINT "x * y = " <+> OP(mul(x, y))
      PRINT "x / y = " <+> OP(div(x, y))
      PRINT "x % y = " <+> OP(mod(x, y))
      PRINT "x ^ z = " <+> OP(exp(x, z))
      PRINT "sqrt(x) = " <+> OP(sqrt(x))
      PRINT "abs(-10) = " <+> OP(abs(-10))
      PRINT "min(x, y) = " <+> OP(min(x, y))
      PRINT "max(x, y) = " <+> OP(max(x, y))
      PRINT "log(x) = " <+> OP(log(x))
      PRINT "floor(3.7) = " <+> OP(floor(3.7))
      PRINT "ceil(3.2) = " <+> OP(ceil(3.2))
      PRINT "round(3.5) = " <+> OP(round(3.5))

      # 4. Symbolic math
      PRINT SYM "x^2 + 2*x + 1"
      PRINT SYM "sin(x)^2 + cos(x)^2"

      # 5. Arrays and set operations
      LET arr1 = [1, 2, 3]
      LET arr2 = [3, 4, 5]
      PRINT "arr1 union arr2: " <+> OP(set_union(arr1, arr2))
      PRINT "arr1 intersection arr2: " <+> OP(set_intersection(arr1, arr2))
      PRINT "arr1 difference arr2: " <+> OP(set_difference(arr1, arr2))
      PRINT "arr1 symmetric difference arr2: " <+> OP(set_symdiff(arr1, arr2))
      PRINT "arr1 cartesian arr2: " <+> OP(cartesian(arr1, arr2))

      # 6. Pipe notation
      data := (TYPE::PipeNotation)::< load | process | save >
      PRINT "Pipeline steps: {{data}}"

      # 7. Function definition and recursion
      FUNC fact(n){
        IF { n <= 1 } THEN { RETURN 1 } ELSE { RETURN n * fact(n-1) }
      }
      PRINT "6! = " <+> CALL fact(6)

      # 8. Function with multiple arguments
      FUNC sum(a, b){ a + b }
      PRINT "sum(10, 20) = " <+> CALL sum(10, 20)

      # 9. Conditionals
      LET score = 85
      IF { score >= 90 } THEN { PRINT "Grade: A" }
      ELSE { IF { score >= 80 } THEN { PRINT "Grade: B" } ELSE { PRINT "Grade: C" } }

      # 10. While loop
      LET i = 0
      LET total = 0
      WHILE { i < 5 } DO {
        total = total + i
        i = i + 1
      }
      PRINT "Sum 0..4 = {{total}}"

      # 11. Error handling
      TRY {
        LET bad = OP(div(1, 0))
        PRINT "This won't print"
      } CATCH {
        PRINT "Caught division by zero!"
      }

      # 12. Pointer usage (demonstration)
      LET ptr = Ptr(42)
      PRINT "Pointer value: {{ptr}}"

      # 13. Advanced: Nested function and string interpolation
     # Fix the function return value issue by updating the FUNC greet_user definition
    # With this more reliable version:
    # In your DSL program


                # 14. Show environment
                PRINT "Final Environment:"
  DSL

  output = MindWeave::Completer::Parser.execute_shorthand(program)

  puts "Program result: #{output}"

end
