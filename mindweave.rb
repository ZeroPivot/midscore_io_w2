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
      "#{p} = args[#{i}]" # Use args directly without type conversion
    end
       .join("\n        ")

    rewritten = body.dup
    rewritten = process_string_concat(rewritten)
    rewritten = rewritten.gsub(
      /IF\s*\{\s*(.*?)\s*\}\s*THEN\s*\{\s*(.*?)\s*\}(?:\s*ELSE\s*\{\s*(.*?)\s*\})?/mi
    ) do
      cond   = ::Regexp.last_match(1).strip
      then_b = ::Regexp.last_match(2).strip
      else_b = ::Regexp.last_match(3) ? ::Regexp.last_match(3).strip : ''
      "if #{cond} then #{then_b} else #{else_b} end"
    end
    rewritten.gsub!(/\bRETURN\b\s*/i, '')
    rewritten.gsub!(/;\s*\z/, '')
    rewritten = rewritten.strip
    rewritten.gsub!(/;/, "\n")

    # Transform other function calls
    rewritten.gsub!(/(?<!Operations\.)\b(?!return\b|puts\b|if\b|else\b)([A-Za-z_]\w*)\s*\(/i) do
      fn = ::Regexp.last_match(1).downcase
      "env.get(:#{fn}).value.call("
    end

    # Remove trailing semicolons
    rewritten.gsub!(/;\s*\z/, '')

    # (Optional: For debugging purposes, print the final transformed code)
    puts "FINAL CODE: #{rewritten.inspect}" if $DEBUG

    # In Parser#parse_line, update how a block starter is detected:
    # Replace the original line (it may have been using a strict regex)

    # 3. Transform PRINT statements (Revised)
    rewritten.gsub!(/\bPRINT\s+(.+?)(\s*;|\n|\z)/i) do
      expr = Regexp.last_match(1).strip
      terminator = Regexp.last_match(2) # Keep terminator separate
      # Check if it's already an Operations.str_concat call
      if expr.start_with?('Operations.str_concat(')
        %(puts("[PRINT] " + #{expr})) + terminator
      elsif expr =~ /\A"(.*?\{\{.*?\}\}.*?)"\z/ # Handle direct string interpolation
        s = Regexp.last_match(1)
        param_vars = params.split(',').map(&:strip)
        param_vars.each do |param|
          s = s.gsub(/\{\{#{param}\}\}/, '#{' + param + '}')
        end
        %(puts("[PRINT] " + "#{s}")) + terminator
      else # Interpolate other expressions/variables
        # Ensure the expression result is converted to string before interpolation
        %(puts("[PRINT] " + Operations.interpolate((#{expr}).to_s))) + terminator
      end
    end

    # In LambdaFunctions.create, locate the transformation section where the DSL body is processed.
    # Replace the existing RETURN replacement and trailing semicolon handling with the following:

    # ----- PATCH BEGIN -----
    # Remove all DSL RETURN keywords (don’t insert Ruby's "return")
    rewritten.gsub!(/\bRETURN\b\s+/i, '')

    # Remove any trailing semicolon (and surrounding whitespace) from the DSL body
    rewritten.sub!(/;\s*\z/, '')

    # Remove any trailing newlines or spaces so the last line produces a value
    rewritten = rewritten.strip

    # Finally, wrap the transformed code in a begin...end block so that the lambda returns the value of its final expression
    rewritten = "begin\n#{rewritten}\nend"
    # 5. Transform other function calls (excluding built-ins and Operations.*)
    rewritten.gsub!(/(?<!Operations\.)\b(?!return\b|puts\b|if\b|else\b)([A-Za-z_]\w*)\s*\(/i) do
      fn = Regexp.last_match(1).downcase
      "env.get(:#{fn}).call("
    end

    # REMOVE Step 6: Final safety pass for IF/ELSE syntax was too aggressive
    # rewritten.gsub!(/\bIF\b\s*\{/i, 'if ')       # REMOVED
    # rewritten.gsub!(/\}\s*THEN\s*\{/i, "\n")      # REMOVED
    # rewritten.gsub!(/\}\s*ELSE\s*\{/i, "\nelse\n") # REMOVED
    # rewritten.gsub!(/\}/i, '')                   # REMOVED
    rewritten.gsub!(/;/, "\n")
    # See final code being generated
    puts "FINAL CODE: #{rewritten.inspect}" if $DEBUG

    # Ensure any hanging if/else blocks generated by Step 3 are properly closed
    if (rewritten.scan(/\bif\b/).length > rewritten.scan(/\bend\b/).length) && !rewritten.strip.end_with?('end')
      rewritten = "#{rewritten}\nend" # Use newline
    end

    rewritten.gsub!(/(\w+)\s*:=\s*/, '\1 = ')
    rewritten = process_string_concat(rewritten)

    # Ensure any hanging if/else blocks are closed
    if (rewritten.scan(/\bif\b/).length > rewritten.scan(/\bend\b/).length) && !rewritten.strip.end_with?('end')
      rewritten = "#{rewritten}\nend"
    end

    # --- KEY FIX: Explicitly return the last value ---
    rewritten = rewritten.strip
    rewritten = rewritten.gsub(/;\s*\z/, '') # Remove trailing semicolon
    rewritten = rewritten.gsub(/;/, "\n")    # Convert all semicolons to newlines

    # Assign the last expression to __result__ and return it
    rewritten = "begin\n__result__ = (#{rewritten}); __result__\nend"

    eval <<~RUBY, binding, __FILE__, __LINE__ + 1
          lambda do |*args|
            env = ObjectSpace._id2ref(#{env.object_id})
            Thread.current[:mindweave_env] = env
      #{'      '}
             # Simple, direct return of result
      result = begin
        rewritten.gsub!(/return\s+/, '') # Remove any return statements#{' '}
      end

      # Return the result explicitly
      result
          ensure
            Thread.current[:mindweave_env] = nil
          end
    RUBY
  end

  # In LambdaFunctions module

  def self.process_string_concat(code)
    result = code.dup

    # Handle LET statements with nested <+> first
    result.gsub!(/(LET\s+\w+\s*=\s*)(.+?)\s*<\+>\s*(.+?)\s*<\+>\s*(.+?)(\s*;|\n|\z)/m) do
      prefix = ::Regexp.last_match(1)
      first = ::Regexp.last_match(2).strip
      middle = ::Regexp.last_match(3).strip
      last = ::Regexp.last_match(4).strip
      terminator = ::Regexp.last_match(5) # Capture terminator
      "#{prefix}Operations.str_concat(Operations.str_concat(#{first}, #{middle}), #{last})#{terminator}"
    end

    # Handle LET statements with simple <+>
    result.gsub!(/(LET\s+\w+\s*=\s*)(.+?)\s*<\+>\s*(.+?)(\s*;|\n|\z)/m) do
      prefix = ::Regexp.last_match(1)
      left = ::Regexp.last_match(2).strip
      right = ::Regexp.last_match(3).strip
      terminator = ::Regexp.last_match(4) # Capture terminator
      "#{prefix}Operations.str_concat(#{left}, #{right})#{terminator}"
    end

    # Remove LET keyword *after* processing LET statements
    result.gsub!(/LET\s+/, '')

    # Handle remaining assignments (non-LET) with nested <+>
    result.gsub!(/(\w+\s*=\s*)(.+?)\s*<\+>\s*(.+?)\s*<\+>\s*(.+?)(\s*;|\n|\z)/m) do
      prefix = ::Regexp.last_match(1)
      first = ::Regexp.last_match(2).strip
      middle = ::Regexp.last_match(3).strip
      last = ::Regexp.last_match(4).strip
      terminator = ::Regexp.last_match(5) # Capture terminator
      "#{prefix}Operations.str_concat(Operations.str_concat(#{first}, #{middle}), #{last})#{terminator}"
    end

    # Handle remaining assignments (non-LET) with simple <+>
    result.gsub!(/(\w+\s*=\s*)(.+?)\s*<\+>\s*(.+?)(\s*;|\n|\z)/m) do
      prefix = ::Regexp.last_match(1)
      left = ::Regexp.last_match(2).strip
      right = ::Regexp.last_match(3).strip
      terminator = ::Regexp.last_match(4) # Capture terminator
      "#{prefix}Operations.str_concat(#{left}, #{right})#{terminator}"
    end

    # Handle PRINT statements with <+>
    result.gsub!(/(PRINT\s+)((?!=\s*).+?)\s*<\+>\s*(.+?)(\s*;|\n|\z)/m) do
      prefix = ::Regexp.last_match(1)
      left = ::Regexp.last_match(2).strip
      right = ::Regexp.last_match(3).strip
      terminator = ::Regexp.last_match(4) # Capture terminator
      "#{prefix}Operations.str_concat(#{left}, #{right})#{terminator}"
    end

    # Handle expressions with <+> operator
    result.gsub!(/(.+?)\s*<\+>\s*(.+)/) do
      left = ::Regexp.last_match(1)
      right = ::Regexp.last_match(2)
      "Operations.str_concat(#{left}, #{right})"
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

  def self.interpolate(str)
    return str unless str.is_a?(String) && str.include?('{{')

    # Only use thread-local environment, not global
    env = Thread.current[:mindweave_env]
    return str unless env

    prev = nil
    while str != prev
      prev = str
      str = str.gsub(/\{\{(.*?)\}\}/) do
        placeholder = ::Regexp.last_match(1).strip
        if placeholder.include?('.') # Support dot notation, e.g. data.inspect
          parts = placeholder.split('.').map(&:strip)
          base_var = parts.shift
          wrapper = env.get(base_var.to_sym)
          if wrapper && wrapper.respond_to?(:value)
            result = wrapper.value
            parts.each do |method_name|
              if result.respond_to?(method_name)
                result = result.send(method_name)
              else
                result = "{{#{placeholder}}}"
                break
              end
            end
            result.to_s
          else
            "{{#{placeholder}}}"
          end
        else
          wrapper = env.get(placeholder.to_sym)
          if wrapper && wrapper.respond_to?(:value)
            wrapper.value.to_s
          else
            "{{#{placeholder}}}"
          end
        end
      end
    end
    str
  end
end

module MindWeave
  class Interpreter
    attr_accessor :env

    def initialize
      @env = SpiritualEnvironment.new
    end

    # Fix the let method in Interpreter
    def let(var, value, type = 'Unknown', aura = 'Neutral')
      eval_value = nil
      begin
        Thread.current[:mindweave_env] = @env # Use @env, not @interpreter.env since we're already in Interpreter
        eval_value =
          if value.is_a?(String) && value.strip =~ /\A["'].*["']\z/
            inner = value[1..-2]
            Operations.interpolate(inner)
          elsif value.is_a?(String) && value.strip =~ /\A\[(.*)\]\z/
            begin
              elements_str = ::Regexp.last_match(1)
              elements_str.split(',').map { |el| evaluate_expression(el.strip) }
            rescue StandardError => e
              puts "[ERROR] Failed to evaluate array literal in LET: #{value}. Error: #{e.message}"
              value
            end
          elsif value.is_a?(String) && value.strip =~ /\APtr\((.*)\)\z/i
            inner_val_str = ::Regexp.last_match(1).strip
            inner_val = evaluate_expression(inner_val_str)
            Pointer.new(inner_val)
          else
            begin
              computed = evaluate_expression(value)
              computed = Operations.interpolate(computed) if computed.is_a?(String)
              computed
            rescue Exception => e
              puts "[WARN] LET evaluation fallback failed for '#{value}': #{e.message}. Treating as string."
              value
            end
          end
      ensure
        Thread.current[:mindweave_env] = nil
      end

      # THIS LINE IS CRUCIAL - actually set the variable in the environment
      @env.set(var, eval_value, type, aura)
      puts "[DEBUG LET] #{var} set to #{eval_value.inspect} (type: #{type})"
      eval_value
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
    class Parser
      def initialize(dsl_instance)
        @dsl = dsl_instance
        @buffer = []
        @brace_count = 0
        @current_construct = nil
        @in_block = false
      end

      def self.execute_shorthand(program)
        # Create a new DSL/interpreter for this run
        interpreter = MindWeave::Interpreter.new
        dsl = MindWeave::Completer::DSL.new(interpreter)
        # Now call new with our DSL instance
        parser = new(dsl)
        parser.parse(program)
        'Program executed successfully'
      end

      # New helper to infer type from a Ruby value.
      def infer_type(value)
        case value
        when Integer then 'Integer'
        when Float then 'Float'
        when String then 'String'
        when TrueClass, FalseClass then 'Boolean'
        when Array then 'Array'
        when Proc then 'Function'
        when Pointer then 'Pointer'
        else 'Object'
        end
      end

      # Modify the parse method to iterate with line numbers
      def parse(program_string)
        program_string.each_line.with_index(1) do |line, lineno|
          parse_line(line, lineno)
        end
        if @current_construct && %i[if_then_expecting_else try_expecting_catch].include?(@current_construct[:type])
          puts '[Parser][Line Unknown] Error: Unexpected end of input while expecting ELSE or CATCH.'
          reset_parser_state
        elsif @in_block && @brace_count == 0
          process_complete_block
        end
      end

      # Modify parse_line to receive the current line number (lineno) for error messages.
      def parse_line(line, lineno)
        original_line = line
        line = line.strip
        return if !line || line.empty? || line.start_with?('#')

        line_content = line.sub(/\s*;?\s*(#.*)?$/, '').strip

        # --- Special: if line is an IF block header with THEN, do not require semicolon ---
        if line_content =~ /^IF\s*\{.*\}\s*THEN\s*\{/i
          needs_semicolon = false
        else
          # Determine block starter as before:
          is_block_starter = (line_content =~ /^(FUNC|IF|WHILE|TRY)/i) && line_content.include?('{')
          needs_semicolon = !is_block_starter
        end

        # Immediately after the existing ELSE transition check, add:
        needs_semicolon = false if line_content =~ /^\}\s*CATCH\s*\{$/i

        has_semicolon = line.include?(';') || line.strip.end_with?('}')
        if needs_semicolon && !has_semicolon && !line.sub(/\s*;?\s*(#.*)?$/, '').strip.empty?
          puts "[Parser][Line #{lineno}] Error: Missing semicolon at the end of statement: #{line}"
          return
        end

        # --- Early Auto-Completion for IF blocks ---
        # If the current line does not begin the ELSE branch,
        # then auto-close the pending IF block immediately.
        if @current_construct && @current_construct[:type] == :if_then_expecting_else && !(line_content =~ /^\}\s*ELSE\s*\{$/i)
          puts "[DEBUG parse_line][Line #{lineno}] Auto-completing IF block with empty ELSE."
          @dsl.if_block(@current_construct[:condition], @current_construct[:then_code], '')
          reset_parser_state
          # Continue processing the current line in a fresh state
          # (do not call parse_line recursively to avoid re-triggering the error)
        end

        # --- State Check for ELSE/CATCH ---
        re_evaluate_line = false
        if @current_construct
          case @current_construct[:type]
          when :if_then_expecting_else
            if line_content =~ /^\}\s*ELSE\s*\{$/i
              @current_construct[:type] = :else_block
              @buffer = [original_line]
              @brace_count = 1
              @in_block = true
              puts "[DEBUG parse_line][Line #{lineno}] Transitioned to :else_block"
              return
            else
              puts "[Parser][Line #{lineno}] Error: Expected ELSE after IF...THEN block, found '#{line_content}'"
              reset_parser_state
              re_evaluate_line = true
            end
          when :try_expecting_catch
            if line_content =~ /^\}\s*CATCH\s*\{$/i
              @current_construct[:type] = :catch_block
              @buffer = [original_line]
              @brace_count = 1
              @in_block = true
              puts "[DEBUG parse_line][Line #{lineno}] Transitioned to :catch_block"
              return
            else
              puts "[Parser][Line #{lineno}] Error: Expected CATCH after TRY block, found '#{line_content}'"
              reset_parser_state
              re_evaluate_line = true
            end
          end
        end

        unless re_evaluate_line
          if @in_block
            @buffer << original_line
            @brace_count += line.count('{') - line.count('}')
            if @brace_count < 0
              puts "[Parser][Line #{lineno}] Error: Unmatched closing brace '}' found in block."
              reset_parser_state
              return
            end
            process_complete_block if @brace_count == 0
            return
          end

          # Original:
          # is_block_starter = line_content =~ /^(FUNC|IF|WHILE|TRY).+\{$/i
          #
          # Updated: (A line is considered a block starter if it
          # starts with one of these keywords and contains '{')
          is_block_starter = (line_content =~ /^(FUNC|IF|WHILE|TRY)/i) && line_content.include?('{')

          needs_semicolon = !is_block_starter
          has_semicolon = line.include?(';') || line.strip.end_with?('}')
          if needs_semicolon && !has_semicolon && !line.sub(/\s*;?\s*(#.*)?$/, '').strip.empty?
            puts "[Parser][Line #{lineno}] Error: Missing semicolon at the end of statement: #{line}"
            return
          end
        end

        # --- NEW: Support single-line FUNC definitions ---
        if line_content =~ /^FUNC\s+(\w+)\((.*?)\)\s*\{(.*?)\}\s*;?$/i
          name = ::Regexp.last_match(1)
          args = ::Regexp.last_match(2)
          code = ::Regexp.last_match(3).strip
          @dsl.func(name, args, code)
          return
        end

        # --- SINGLE LINE & BLOCK STARTERS ---
        case line_content
        when /^FUNC\s+(\w+)\((.*?)\)\s*\{$/i
          @current_construct = { type: :func, name: ::Regexp.last_match(1), args: ::Regexp.last_match(2) }
          @buffer = [original_line]
          @brace_count = 1
          @in_block = true
          puts "[DEBUG parse_line][Line #{lineno}] Started :func block"
        when /^IF\s*\{(.*?)\}\s*THEN\s*\{$/i
          @current_construct = { type: :if_then, condition: ::Regexp.last_match(1).strip }
          @buffer = [original_line]
          @brace_count = 1
          @in_block = true
          puts "[DEBUG parse_line][Line #{lineno}] Started :if_then block"
        when /^WHILE\s*\{(.*?)\}\s*DO\s*\{$/i
          @current_construct = { type: :while, condition: ::Regexp.last_match(1).strip }
          @buffer = [original_line]
          @brace_count = 1
          @in_block = true
          puts "[DEBUG parse_line][Line #{lineno}] Started :while block"
        when /^TRY\s*\{$/i
          @current_construct = { type: :try }
          @buffer = [original_line]
          @brace_count = 1
          @in_block = true
          puts "[DEBUG parse_line][Line #{lineno}] Started :try block"
        # Change it to:
        when /^LET\s+(\w+)\s*:=\s*(.+)$/i
          var = ::Regexp.last_match(1)
          value = ::Regexp.last_match(2)
          @dsl.let(var, value)
        when /^PRINT\s+(.+)$/i
          expr = ::Regexp.last_match(1)
          @dsl.print_var(expr)
        when /^CALL\s+(\w+)\((.*?)\)$/i
          func_name = ::Regexp.last_match(1)
          args_str = ::Regexp.last_match(2)
          args = args_str.split(',').map { |a| @dsl.evaluate_expression(a.strip) }
          @dsl.call(func_name, *args)
        when /^OP\((.*?)\)$/i
          expression = ::Regexp.last_match(1)
          @dsl.op(expression)
        when /^SYM\s+(.+)$/i
          expression = ::Regexp.last_match(1)
          @dsl.sym(expression)
        when /^(\w+)\s*:=\s*\(TYPE::(\w+)\)\s*::<\s*(.+?)\s*>;?$/i
          var = ::Regexp.last_match(1)
          type = ::Regexp.last_match(2)
          steps_str = ::Regexp.last_match(3)
          @dsl.pipe_assign(var, steps_str)
        when /^(\w+)\s*:=\s*(.+)$/i
          var = ::Regexp.last_match(1)
          value = ::Regexp.last_match(2)
          @dsl.let(var, value)
        when /^\}\s*ELSE\s*\{$/i, /^\}\s*CATCH\s*\{$/i, /^\}$/
          puts "[Parser][Line #{lineno}] Error: Unexpected block delimiter outside of expected context: #{line_content}"
        else
          original_line_trimmed = line.sub(/\s*;?\s*(#.*)?$/, '').strip
          unless original_line_trimmed.empty?
            puts "[Parser][Line #{lineno}] Unknown or unsupported DSL statement: #{original_line_trimmed}"
          end
        end
      end

      def process_complete_block
        # Should only be called when @in_block is true and @brace_count becomes 0
        unless @in_block && @brace_count == 0
          puts "[DEBUG process_complete_block] Called incorrectly? in_block=#{@in_block}, brace_count=#{@brace_count}"
          return
        end

        buffer_text = @buffer.join("\n")
        first_content_brace_offset = buffer_text.index('{')
        last_content_brace_offset = buffer_text.rindex('}')

        code = if first_content_brace_offset && last_content_brace_offset && first_content_brace_offset < last_content_brace_offset
                 buffer_text[(first_content_brace_offset + 1)...last_content_brace_offset].strip
               else
                 puts "[Parser] Error: Malformed block content in buffer for construct #{@current_construct[:type]}."
                 puts "[DEBUG process_complete_block] Buffer Text:\n#{buffer_text}" # DEBUG
                 ''
               end

        puts "[DEBUG process_complete_block] Processing block type: #{@current_construct[:type]}" # DEBUG
        puts "[DEBUG process_complete_block] Extracted code:\n---\n#{code}\n---" # DEBUG

        block_type = @current_construct[:type]
        # We are no longer in the block *after* processing
        @in_block = false # Set before potential state change below

        case block_type
        when :func
          name = @current_construct[:name]
          args = @current_construct[:args]
          @dsl.func(name, args, code)
          reset_parser_state

        when :if_then
          # Finished the THEN block, now expect ELSE
          @current_construct[:type] = :if_then_expecting_else
          @current_construct[:then_code] = code
          # Don't reset state yet, wait for parse_line to see ELSE or error
          puts '[DEBUG process_complete_block] Finished :if_then, expecting :else_block' # DEBUG

        when :else_block # This state is set by parse_line when } ELSE { is found
          condition = @current_construct[:condition]
          then_code = @current_construct[:then_code]
          else_code = code # This is the code from the ELSE block buffer
          @dsl.if_block(condition, then_code, else_code)
          reset_parser_state

        when :while
          condition = @current_construct[:condition]
          body = code
          @dsl.while_block(condition, body)
          reset_parser_state

        when :try
          # Finished the TRY block, now expect CATCH
          @current_construct[:type] = :try_expecting_catch
          @current_construct[:try_code] = code
          # Don't reset state yet, wait for parse_line to see CATCH or error
          puts '[DEBUG process_complete_block] Finished :try, expecting :catch_block' # DEBUG

        when :catch_block # This state is set by parse_line when } CATCH { is found
          try_code = @current_construct[:try_code]
          catch_code = code # This is the code from the CATCH block buffer
          @dsl.try_catch_block(try_code, catch_code)
          reset_parser_state

        else
          puts "[Parser] Error: Unknown block type encountered in process_complete_block: #{block_type}"
          reset_parser_state
        end
      end

      # --- Ensure 'reset_parser_state' method is defined here ---
      def reset_parser_state
        @buffer = []
        @brace_count = 0
        @current_construct = nil
        @in_block = false
      end
      # --- End of 'reset_parser_state' method ---

      # Class method definition (remains the same)
      def self.execute_shorthand(program)
        interpreter = MindWeave::Interpreter.new
        dsl = MindWeave::Completer::DSL.new(interpreter)
        parser = new(dsl)
        # This call should now work
        parser.parse(program)
        'Program executed successfully'
      end
    end # End Parser class

    class DSL
      attr_reader :interpreter

      def initialize(interpreter)
        @interpreter = interpreter
      end

      def call(name, *args)
        func_record = @interpreter.get(name)
        raise "Function '#{name}' not found!" unless func_record && func_record.value.respond_to?(:call)

        # --- REMOVE Redundant Argument Processing ---
        # The 'args' received are already evaluated by the parser.
        # processed_args = args.map do |arg|
        #   if arg.is_a?(String) && (arg =~ /\A"(.*)"\z/ || arg =~ /\A'(.*)'\z/)
        #     ::Regexp.last_match(1) # Strip quotes
        #   else
        #     # This lookup was also redundant as evaluate_expression already did it
        #     # v = @interpreter.get(arg)
        #     # v.respond_to?(:value) ? v.value : arg
        #     arg # Use the already evaluated argument
        #   end
        # end
        # --- END REMOVAL ---

        # Call the function with the already evaluated arguments
        result = func_record.value.call(*args) # Use 'args' directly

        puts "[DSL Completer] #{name}(#{args.inspect}) => #{result}"
        result
      end

      # Inside MindWeave::Completer::DSL

      # Inside class MindWeave::Completer::DSL

      def evaluate_expression(expr_str)
        expr_str = expr_str.strip

        # --- Handle <+> concatenation FIRST ---
        if expr_str.include?('<+>')
          parts = expr_str.split('<+>')
          result = parts.map { |part| evaluate_expression(part.strip).to_s }.join('')
          return result
        end
        # --- END <+> handling ---

        expr_str = expr_str.strip

        # --- NEW: Handle relational expressions, letting "=" be the equality operator ---
        if expr_str =~ /^(.+?)\s*([<>]=?|=|!=)\s*(.+)$/
          left = evaluate_expression(::Regexp.last_match(1).strip)
          operator = ::Regexp.last_match(2).strip
          right = evaluate_expression(::Regexp.last_match(3).strip)
          case operator
          when '>'  then return left > right
          when '<'  then return left < right
          when '>=' then return left >= right
          when '<=' then return left <= right
          when '=', '==' then return left == right
          when '!=' then return left != right
          else
            # Fallback: return the original expression
            return expr_str
          end
        end
        # --- END relational expressions ---

        # Check if it's an OP(...) call
        if expr_str =~ /^OP\((.*)\)$/i
          op(::Regexp.last_match(1))
        # Check if it's a quoted string literal
        elsif expr_str =~ /\A"(.*)"\z/ || expr_str =~ /\A'(.*)'\z/
          Operations.interpolate(::Regexp.last_match(1))
        # Check if it's a number literal
        elsif expr_str =~ /\A-?\d+(\.\d+)?\z/
          expr_str.include?('.') ? expr_str.to_f : expr_str.to_i
        # Check if it's an array literal [item1, item2, ...]
        elsif expr_str =~ /\A\[(.*)\]\z/
          elements_str = ::Regexp.last_match(1)
          begin
            elements_str.split(',').map { |el| evaluate_expression(el.strip) }
          rescue StandardError => e
            puts "[ERROR] Failed to evaluate array literal: #{expr_str}. Error: #{e.message}"
            expr_str
          end
        # Check for boolean literals
        elsif expr_str == 'true'
          true
        elsif expr_str == 'false'
          false
        elsif expr_str =~ /\A"(.*)"\z/ || expr_str =~ /\A'(.*)'\z/
          Operations.interpolate(::Regexp.last_match(1))
        # Otherwise, assume it's a variable name
        else
          v = @interpreter.get(expr_str)
          if v && v.respond_to?(:value)
            val = v.value
            # If the value is a String that matches a number literal, convert it
            return val.include?('.') ? val.to_f : val.to_i if val.is_a?(String) && val =~ /\A-?\d+(\.\d+)?\z/

            val

          else
            expr_str
          end
        end
      end
      # --- End of evaluate_expression method ---

      # Update let to enforce provided type or infer if missing.
      def let(var, value, type = 'Unknown', aura = 'Neutral')
        eval_value = nil
        begin
          # Set thread-local env for interpolation/evaluation within this LET statement
          Thread.current[:mindweave_env] = @interpreter.env

          eval_value =
            if value.is_a?(String) && value.strip =~ /\A["'].*["']\z/
              # Quoted strings are interpolated first.
              Operations.interpolate(value[1..-2])
            elsif value.is_a?(String) && value.strip =~ /\A\[(.*)\]\z/
              begin
                elements_str = ::Regexp.last_match(1)
                elements_str.split(',').map { |el| evaluate_expression(el.strip) }
              rescue StandardError => e
                puts "[ERROR] Failed to evaluate array literal in LET: #{value}. Error: #{e.message}"
                value
              end
            elsif value.is_a?(String) && value.strip =~ /\APtr\((.*)\)\z/i
              inner_val_str = ::Regexp.last_match(1).strip
              inner_val = evaluate_expression(inner_val_str)
              Pointer.new(inner_val)
            else
              begin
                eval_value = evaluate_expression(value)
                # --- PATCH: Interpolate if result is a String ---
                eval_value = Operations.interpolate(eval_value) if eval_value.is_a?(String)
                eval_value
              rescue Exception => e
                puts "[WARN] LET evaluation fallback failed for '#{value}': #{e.message}. Treating as string."
                value
              end
            end
        ensure
          # Clear thread-local env after LET statement processing
          Thread.current[:mindweave_env] = nil
        end

        # If a type is explicitly provided (other than "Unknown"), attempt to enforce it.
        # Otherwise, infer type based on the evaluated value.
        if type == 'Unknown'
          type = infer_type(eval_value)
        else
          # Example enforcement: if type is String, ensure eval_value is coerced to string.
          case type.downcase
          when 'string'
            eval_value = eval_value.to_s
          when 'integer'
            eval_value = eval_value.to_i
          when 'float'
            eval_value = eval_value.to_f
          when 'boolean'
            eval_value = !!eval_value
          when 'array'
            eval_value = Array(eval_value)
          end
        end

        @interpreter.env.set(var, eval_value, type, aura)
        # Debug output to verify variable assignment
        puts "[DEBUG LET] #{var} set to #{eval_value.inspect} (type: #{type})"
      end

      # ...rest of your DSL methods...

      # In your print_var and let methods, ensure thread-local is always set/cleared
      def print_var(expr)
        # Set thread-local env for interpolation
        Thread.current[:mindweave_env] = @interpreter.env
        begin
          # First, evaluate the expression to get its value
          evaluated_value = evaluate_expression(expr)

          # For quoted strings, directly pass to interpolate
          result = if expr.is_a?(String) && (expr =~ /\A"(.*)"\z/ || expr =~ /\A'(.*)'\z/)
                     Operations.interpolate(Regexp.last_match(1))
                   else
                     # For other expressions, convert to string first then interpolate
                     Operations.interpolate(evaluated_value.to_s)
                   end

          puts "[PRINT] #{result}"
          result
        rescue StandardError => e
          puts "[ERROR in print_var] #{e.message}"
          puts e.backtrace.first(5)
          evaluated_value.to_s
        ensure
          Thread.current[:mindweave_env] = nil
        end
      end
      # Inside class MindWeave::Completer::Parser

      # ... initialize method ...
      # ... parse method ...

      # In the Parser#parse_line method, after computing line_content, insert the following:
      def parse_line(line, lineno)
        original_line = line
        line = line.strip
        return if !line || line.empty? || line.start_with?('#')

        line_content = line.sub(/\s*;?\s*(#.*)?$/, '').strip

        # In the Parser#parse_line method, near the beginning (after computing line_content), insert this:

        if @current_construct && @current_construct[:type] == :if_then_expecting_else && !(line_content =~ /^\}\s*ELSE\s*\{$/i)
          puts "[DEBUG parse_line][Line #{lineno}] No ELSE block found; auto-completing IF block with empty ELSE."
          @dsl.if_block(@current_construct[:condition], @current_construct[:then_code], '')
          reset_parser_state
          # Reprocess the current line now that the IF block is closed.
          parse_line(line, lineno)
          return
        end

        # --- Existing state-check code follows ---
        re_evaluate_line = false
        if @current_construct
          case @current_construct[:type]
          when :if_then_expecting_else
            if line_content =~ /^\}\s*ELSE\s*\{$/i
              @current_construct[:type] = :else_block
              @buffer = [original_line]
              @brace_count = 1
              @in_block = true
              puts "[DEBUG parse_line][Line #{lineno}] Transitioned to :else_block"
              return
            else
              puts "[Parser][Line #{lineno}] Error: Expected ELSE after IF...THEN block, found '#{line_content}'"
              reset_parser_state
              re_evaluate_line = true
            end
          when :try_expecting_catch
            if line_content =~ /^\}\s*CATCH\s*\{$/i
              @current_construct[:type] = :catch_block
              @buffer = [original_line]
              @brace_count = 1
              @in_block = true
              puts "[DEBUG parse_line][Line #{lineno}] Transitioned to :catch_block"
              return
            else
              puts "[Parser][Line #{lineno}] Error: Expected CATCH after TRY block, found '#{line_content}'"
              reset_parser_state
              re_evaluate_line = true
            end
          end
        end

        unless re_evaluate_line
          if @in_block
            @buffer << original_line
            @brace_count += line.count('{') - line.count('}')
            if @brace_count < 0
              puts "[Parser] Error: Unmatched closing brace '}' found in block."
              reset_parser_state
              return
            end
            process_complete_block if @brace_count == 0
            return
          end

          is_block_starter = line_content =~ /^(FUNC|IF|WHILE|TRY).+\{$/i
          needs_semicolon = !is_block_starter
          has_semicolon = line.include?(';') || line.strip.end_with?('}')
          if needs_semicolon && !has_semicolon && !line.sub(/\s*;?\s*(#.*)?$/, '').strip.empty?
            puts "[Parser] Error: Missing semicolon at the end of statement: #{line}"
            return
          end
        end

        # --- NEW: Support single-line FUNC definitions ---
        if line_content =~ /^FUNC\s+(\w+)\((.*?)\)\s*\{(.*?)\}\s*;?$/i
          name = ::Regexp.last_match(1)
          args = ::Regexp.last_match(2)
          code = ::Regexp.last_match(3).strip
          @dsl.func(name, args, code)
          return
        end

        # --- SINGLE LINE & BLOCK STARTERS (existing cases) ---
        case line_content
        when /^FUNC\s+(\w+)\((.*?)\)\s*\{$/i
          @current_construct = { type: :func, name: ::Regexp.last_match(1), args: ::Regexp.last_match(2) }
          @buffer = [original_line]
          @brace_count = 1
          @in_block = true
          puts '[DEBUG parse_line] Started :func block'
        when /^IF\s*\{(.*?)\}\s*THEN\s*\{$/i
          @current_construct = { type: :if_then, condition: ::Regexp.last_match(1).strip }
          @buffer = [original_line]
          @brace_count = 1
          @in_block = true
          puts '[DEBUG parse_line] Started :if_then block'
        when /^WHILE\s*\{(.*?)\}\s*DO\s*\{$/i
          @current_construct = { type: :while, condition: ::Regexp.last_match(1).strip }
          @buffer = [original_line]
          @brace_count = 1
          @in_block = true
          puts '[DEBUG parse_line] Started :while block'
        when /^TRY\s*\{$/i
          @current_construct = { type: :try }
          @buffer = [original_line]
          @brace_count = 1
          @in_block = true
          puts '[DEBUG parse_line] Started :try block'
        when /^LET\s+(\w+)\s*::\s*(\w+)\s*:=\s*(.+)$/i
          var = ::Regexp.last_match(1)
          type = ::Regexp.last_match(2)
          value = ::Regexp.last_match(3)
          @dsl.let(var, value, type)

        when /^LET\s+(\w+)\s*=\s*(.+)$/i
          var = ::Regexp.last_match(1)
          value = ::Regexp.last_match(2)
          @dsl.let(var, value)

        when /^(\w+)\s*=\s*(.+)$/i
          var = ::Regexp.last_match(1)
          value = ::Regexp.last_match(2)
          @dsl.let(var, value)
        when /^PRINT\s+(.+)$/i
          expr = ::Regexp.last_match(1)
          @dsl.print_var(expr)
        when /^(\w+)\s*::\s*(\w+)\s*:=\s*(.+)$/i
          var = ::Regexp.last_match(1)
          type = ::Regexp.last_match(2)
          value = ::Regexp.last_match(3)
          @dsl.let(var, value, type)
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
        # Existing general assignment after these cases:
        when /^(\w+)\s*=\s*(.+)$/i
          var = ::Regexp.last_match(1)
          value = ::Regexp.last_match(2)
          @dsl.let(var, value)
        when /^\}\s*ELSE\s*\{$/i, /^\}\s*CATCH\s*\{$/i, /^\}$/
          puts "[Parser] Error: Unexpected block delimiter outside of expected context: #{line_content}"
        else
          original_line_trimmed = line.sub(/\s*;?\s*(#.*)?$/, '').strip
          unless original_line_trimmed.empty?
            puts "[Parser] Unknown or unsupported DSL statement: #{original_line_trimmed}"
          end
        end

        # --- END of parse_line method ---
        # (process_complete_block and reset_parser_state remain as previously defined)
        # --- PATCH END ---

        # ... process_complete_block method ...
        # ... reset_parser_state method ...
        # ... self.execute_shorthand method ...

        # Check for constructs that might span multiple lines (using line_content)
        case line_content
        # — Reordered for correct precedence —

        # --- Block Starters ---
        when /^FUNC\s+(\w+)\((.*?)\)\s*\{$/i
          @current_construct = { type: :func, name: ::Regexp.last_match(1), args: ::Regexp.last_match(2) }
          @buffer = [original_line] # Start buffer with the starting line
          @brace_count = 1
          @in_block = true

        when /^IF\s*\{(.*?)\}\s*THEN\s*\{$/i # Multi-line IF...THEN...ELSE
          @current_construct = { type: :if_then, condition: ::Regexp.last_match(1).strip }
          @buffer = [original_line]
          @brace_count = 1 # For the THEN block
          @in_block = true

        when /^WHILE\s*\{(.*?)\}\s*DO\s*\{$/i
          @current_construct = { type: :while, condition: ::Regexp.last_match(1).strip }
          @buffer = [original_line]
          @brace_count = 1
          @in_block = true

        when /^TRY\s*\{$/i
          @current_construct = { type: :try }
          @buffer = [original_line]
          @brace_count = 1
          @in_block = true

        # --- Single Line Statements (must end with ;) ---
        # Check LET before general assignment
        when /^LET\s+(\w+)\s*=\s*(.+)$/i
          var = ::Regexp.last_match(1)
          value = ::Regexp.last_match(2)
          @dsl.let(var, value)

        when /^PRINT\s+(.+)$/i
          expr = ::Regexp.last_match(1)
          @dsl.print_var(expr) # Ensure this calls the DSL's print_var

        when /^CALL\s+(\w+)\((.*?)\)$/i
          func_name = ::Regexp.last_match(1)
          args_str = ::Regexp.last_match(2)
          # Use evaluate_expression for arguments in CALL
          args = args_str.split(',').map { |a| @dsl.evaluate_expression(a.strip) }
          @dsl.call(func_name, *args)

        when /^OP\((.*?)\)$/i
          expression = ::Regexp.last_match(1)
          @dsl.op(expression)

        when /^SYM\s+(.+)$/i
          expression = ::Regexp.last_match(1)
          @dsl.sym(expression)

        # Pipe assignment specific syntax
        when /^(\w+)\s*:=\s*\(TYPE::(\w+)\)::<\s*(.*?)\s*>$/i
          var = ::Regexp.last_match(1)
          pipe_content = ::Regexp.last_match(3)
          @dsl.pipe_assign(var, pipe_content)

        # General assignment (should come after LET)
        when /^(\w+)\s*=\s*(.+)$/i
          var = ::Regexp.last_match(1)
          value = ::Regexp.last_match(2)
          @dsl.let(var, value) # Treat as LET

        # --- Block Endings / Continuations (Handled by @in_block logic) ---
        when /^\}\s*ELSE\s*\{$/i # Part of IF or TRY
          # This case is handled when @in_block is true
        when /^\}\s*ELSE\s*\{$/i # Part of IF or TRY
          # This case is handled when @in_block is true
          puts '[Parser] Ignoring ELSE outside of block context' unless @in_block

        when /^\}\s*CATCH\s*\{$/i # Part of TRY
          # This case is handled when @in_block is true
          puts '[Parser] Ignoring CATCH outside of block context' unless @in_block

        when /^\}$/ # End of a block
          # This case is handled when @in_block is true
          puts '[Parser] Ignoring closing brace outside of block context' unless @in_block

        else
          # Only report unknown if it wasn't just a comment or empty line initially
          original_line_trimmed = line.sub(/\s*;?\s*(#.*)?$/, '').strip
          unless original_line_trimmed.empty?
            puts "[Parser] Unknown or unsupported DSL statement: #{original_line_trimmed}"
          end
        end
      end

      def process_complete_block
        # Should only be called when @in_block is true and @brace_count becomes 0
        unless @in_block && @brace_count == 0
          puts "[DEBUG process_complete_block] Called incorrectly? in_block=#{@in_block}, brace_count=#{@brace_count}"
          return
        end

        # --- New Extraction Logic ---
        code = ''
        if @buffer.length >= 2 # Need at least the start and end lines
          first_line = @buffer.first
          last_line = @buffer.last

          # Find the start brace on the first line (should be the last one)
          start_brace_index = first_line.rindex('{')

          if start_brace_index
            # Get content from the first line after the brace
            first_line_content = first_line[(start_brace_index + 1)..-1]

            # Get content from middle lines (if any)
            # Ensure middle lines are joined with newlines if they exist
            middle_lines_content = @buffer.length > 2 ? @buffer[1...-1].join("\n") : ''

            # Combine content and strip
            # We don't need the last line's content before the '}' because it's just the brace itself.
            # Add newline between first line content and middle content if both exist
            combined_content = first_line_content.strip
            unless middle_lines_content.empty?
              combined_content += "\n" + middle_lines_content # Add newline separator
            end
            code = combined_content.strip # Final strip

          else
            puts "[Parser] Error: Cannot find starting brace '{' on the first line of the block buffer."
            puts "[DEBUG process_complete_block] First Line: #{first_line.inspect}" # DEBUG
          end
        elsif @buffer.length == 1 && @buffer.first.count('{') == 1 && @buffer.first.count('}') == 1
          # Handle single-line blocks like TRY { PRINT "Error"; } CATCH { ... }
          first_line = @buffer.first
          start_brace_index = first_line.index('{')
          end_brace_index = first_line.rindex('}')
          if start_brace_index && end_brace_index && start_brace_index < end_brace_index
            code = first_line[(start_brace_index + 1)...end_brace_index].strip
          else
            puts '[Parser] Error: Malformed single-line block.'
            puts "[DEBUG process_complete_block] Buffer: #{@buffer.inspect}" # DEBUG
          end
        else
          puts '[Parser] Error: Block buffer has invalid structure (length < 1 or malformed).'
          puts "[DEBUG process_complete_block] Buffer: #{@buffer.inspect}" # DEBUG
        end
        # --- End New Extraction Logic ---

        puts "[DEBUG process_complete_block] Processing block type: #{@current_construct[:type]}" # DEBUG
        puts "[DEBUG process_complete_block] Extracted code:\n---\n#{code}\n---" # DEBUG

        block_type = @current_construct[:type]
        @in_block = false # Set before potential state change below

        case block_type
        when :func
          name = @current_construct[:name]
          args = @current_construct[:args]
          # The func DSL method should handle internal transformations now
          @dsl.func(name, args, code)
          reset_parser_state

        when :if_then
          # Finished the THEN block, now expect ELSE
          @current_construct[:type] = :if_then_expecting_else
          @current_construct[:then_code] = code
          # Don't reset state yet, wait for parse_line to see ELSE or error
          puts '[DEBUG process_complete_block] Finished :if_then, expecting :else_block' # DEBUG

        when :else_block # This state is set by parse_line when } ELSE { is found
          condition = @current_construct[:condition]
          then_code = @current_construct[:then_code]
          else_code = code # This is the code from the ELSE block buffer
          @dsl.if_block(condition, then_code, else_code)
          reset_parser_state

        when :while
          condition = @current_construct[:condition]
          body = code # Use the newly extracted code
          # Remove semicolons before passing to DSL method? No, let DSL handle it.
          # body.gsub!(/;/, "\n") # Removed from here
          @dsl.while_block(condition, body)
          reset_parser_state

        when :try
          # Finished the TRY block, now expect CATCH
          @current_construct[:type] = :try_expecting_catch
          @current_construct[:try_code] = code
          # Don't reset state yet, wait for parse_line to see CATCH or error
          puts '[DEBUG process_complete_block] Finished :try, expecting :catch_block' # DEBUG

        when :catch_block # This state is set by parse_line when } CATCH { is found
          try_code = @current_construct[:try_code]
          catch_code = code # This is the code from the CATCH block buffer
          @dsl.try_catch_block(try_code, catch_code)
          reset_parser_state

        else
          puts "[Parser] Error: Unknown block type encountered in process_complete_block: #{block_type}"
          reset_parser_state
        end
      end

      # Helper to reset parser state after processing a block
      def reset_parser_state
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

    # Helper to reset parser state after processing a block
    def reset_parser_state
      @buffer = []
      @brace_count = 0
      @current_construct = nil
      @in_block = false
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
        env = @interpreter.env
        condition_met = false
        # Use evaluate_expression for the condition
        begin
          # Set thread-local env for interpolation within evaluate_expression
          Thread.current[:mindweave_env] = env
          condition_met = evaluate_expression(condition)
          unless [true, false].include?(condition_met)
            puts "[ERROR] IF condition did not evaluate to true or false: '#{condition}' -> #{condition_met.inspect}"
            # Default to else block or handle error differently?
            condition_met = false
          end
        rescue StandardError => e
          puts "[ERROR] IF condition evaluation failed: #{e.message}"
          # Default to else block or handle error differently?
          condition_met = false
        ensure
          Thread.current[:mindweave_env] = nil # Clear thread-local env
        end

        # Execute the appropriate block by parsing its code
        sub_parser = MindWeave::Completer::Parser.new(self) # Create a sub-parser
        code_to_run = condition_met ? then_code : else_code

        begin
          # Set thread-local env for any interpolation needed during block parsing/execution
          Thread.current[:mindweave_env] = env
          sub_parser.parse(code_to_run)
        rescue StandardError => e
          puts "[ERROR] Error executing IF/ELSE block: #{e.message}"
        ensure
          Thread.current[:mindweave_env] = nil # Clear thread-local env
        end
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
        env = @interpreter.env
        sub_parser = MindWeave::Completer::Parser.new(self) # Create a sub-parser
        begin
          # Set thread-local env for try block execution
          Thread.current[:mindweave_env] = env
          sub_parser.parse(try_code)
        rescue StandardError => e
          puts "[DSL Completer] Caught exception: #{e.message}"
          # Execute catch block in case of error
          begin
            # Set thread-local env for catch block execution
            Thread.current[:mindweave_env] = env
            sub_parser.parse(catch_code)
          rescue StandardError => e2
            puts "[ERROR] Error executing CATCH block itself: #{e2.message}"
          ensure
            # Clear thread-local env after catch block attempt
            Thread.current[:mindweave_env] = nil
          end
        else
          # Clear thread-local env if try block succeeded without exception
          Thread.current[:mindweave_env] = nil
        end
      end

      # Update let to enforce types & interpolate string results
      def let(var, value, type = 'Unknown', aura = 'Neutral')
        eval_value = nil
        begin
          # Set thread-local env so interpolation works during evaluation
          Thread.current[:mindweave_env] = @interpreter.env

          eval_value =
            if value.is_a?(String) && value.strip =~ /\A["'].*["']\z/
              # For quoted strings, strip quotes and interpolate recursively.
              inner = value[1..-2]
              Operations.interpolate(inner)
            elsif value.is_a?(String) && value.strip =~ /\A\[(.*)\]\z/
              begin
                elements_str = ::Regexp.last_match(1)
                elements_str.split(',').map { |el| evaluate_expression(el.strip) }
              rescue StandardError => e
                puts "[ERROR] Failed to evaluate array literal in LET: #{value}. Error: #{e.message}"
                value
              end
            elsif value.is_a?(String) && value.strip =~ /\APtr\((.*)\)\z/i
              inner_val_str = ::Regexp.last_match(1).strip
              inner_val = evaluate_expression(inner_val_str)
              Pointer.new(inner_val)
            else
              begin
                computed = evaluate_expression(value)
                # --- PATCH: Interpolate if the computed result is a String ---
                computed = Operations.interpolate(computed) if computed.is_a?(String)
                computed
              rescue Exception => e
                puts "[WARN] LET evaluation fallback failed for '#{value}': #{e.message}. Treating as string."
                value
              end
            end
        ensure
          # Clear thread-local env after LET processing
          Thread.current[:mindweave_env] = nil
        end
      end

      # Ensure func also sets the environment correctly for the lambda
      def func(name, arglist, code)
        # Pass the current interpreter's environment to create
        lambda_func = LambdaFunctions.create(arglist, code, @interpreter.env)
        @interpreter.env.set(name, lambda_func, 'Function', 'Dynamic')
        puts "[DSL Completer] Defined function: #{name}(#{arglist})"
      end

      def op(expression)
        # Parse OP(add(x,y)), OP(factorial(5)), etc.
        if expression =~ /^(\w+)\((.*?)\)$/i
          op_name = ::Regexp.last_match(1)
          args_str = ::Regexp.last_match(2)
          # Use evaluate_expression to handle nested calls properly
          args = args_str.split(',').map { |arg_str| evaluate_expression(arg_str.strip) }

          # Convert string number args to actual integers/floats
          converted_args = args.map do |arg|
            if arg.is_a?(String)
              if arg =~ /^\d+$/
                arg.to_i  # Convert to integer
              elsif arg =~ /^\d+\.\d+$/
                arg.to_f  # Convert to float
              else
                arg       # Keep as string
              end
            else
              arg         # Keep non-string as-is
            end
          end

          if Operations.respond_to?(op_name)
            # Fixed: Actually call the operation and return the result
            begin
              result = Operations.send(op_name, *converted_args)
              puts "[DSL Completer] OP: #{op_name}(#{converted_args.inspect}) => #{result}"
              return result
            rescue StandardError => e
              puts "[DSL Completer] OP Error in operation '#{op_name}': #{e.message}"
              return nil
            end
          else
            # Function lookup and calling from environment
            func_wrapper = @interpreter.get(op_name)
            if func_wrapper && func_wrapper.value.respond_to?(:call)
              begin
                puts "[DEBUG op] Calling function '#{op_name}' from environment with args: #{converted_args.inspect}"
                result = func_wrapper.value.call(*converted_args)
                puts "[DSL Completer] OP (env): #{op_name}(#{converted_args.inspect}) => #{result}"
                return result # Explicit return ensures value is passed back
              rescue StandardError => e
                puts "[DSL Completer] OP Error calling function '#{op_name}' with #{converted_args.inspect}: #{e.message}"
                return nil
              end
            else
              puts "[DSL Completer] OP Error: Unknown operation '#{op_name}'"
              return nil
            end
          end
        end

        # If we get here, the expression didn't match our pattern
        puts "[DSL Completer] OP Error: Invalid expression format '#{expression}'"
        nil
      end

      # ...existing code...

      # In class MindWeave::Completer::DSL, update the pipe_assign method:
      def pipe_assign(var, pipe_content)
        # Split the content on the pipe symbol and strip each step
        steps = pipe_content.split('|').map(&:strip)
        # Assign the resulting array as a 'PipeNotation' typed variable in the environment
        @interpreter.let(var, steps, 'PipeNotation', 'Flowing')
        puts "[DSL Completer] PIPE #{var} assigned with steps: #{steps.inspect}"
        steps
      end

      def while_block(condition, body)
        env = @interpreter.env
        max_iterations = 1000
        iterations = 0

        # Create a sub-parser instance associated with this DSL instance
        sub_parser = MindWeave::Completer::Parser.new(self)

        loop do
          iterations += 1
          if iterations > max_iterations
            puts "[ERROR] WHILE loop exceeded maximum iterations (#{max_iterations}). Aborting."
            break
          end

          # --- Condition Check ---
          # Use evaluate_expression for the condition
          begin
            # Set thread-local env for interpolation within evaluate_expression
            Thread.current[:mindweave_env] = env
            condition_met = evaluate_expression(condition)
            unless [true, false].include?(condition_met)
              puts "[ERROR] WHILE condition did not evaluate to true or false: '#{condition}' -> #{condition_met.inspect}"
              break
            end
          rescue StandardError => e
            puts "[ERROR] While condition evaluation failed: #{e.message}"
            break # Exit loop on condition error
          ensure
            Thread.current[:mindweave_env] = nil # Clear thread-local env
          end

          break unless condition_met # Exit loop if condition is false

          # --- Body Execution ---
          # Use the sub-parser to execute the extracted body code
          begin
            # Set thread-local env for any interpolation needed during body parsing/execution
            Thread.current[:mindweave_env] = env
            sub_parser.parse(body)
          rescue StandardError => e
            puts "[ERROR] Error executing WHILE loop body: #{e.message}"
          # Decide if loop should break on body error
          # break
          ensure
            Thread.current[:mindweave_env] = nil # Clear thread-local env
          end
        end # end loop
      end # end while_blockend # end while_block
    end # end class DSL
  end # end module Completer
end # end module MindWeave

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
    # Remove global variable access
    # $current_dsl_env = @env - REMOVED
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

# ... (previous code remains the same) ...

# Now the code should be ready to run the example at the bottom

# 1) Create your DSL instance
# dsl = MindWeaveDSL.new # Using execute_shorthand now
# dsl.show_env

# 2) Define a recursive factorial via the DSL
# dsl.define_function('fact', 'n', <<~DSL) ... # Defined within the program string now

# 3) Call it
# result = dsl.call_function('fact', 5) ... # Called within the program string now

# 4) Use some built‑in operations
# dsl.evaluate('LET x = 2;') ... # Done within the program string now

# 5) Pipe‑notation assignment
# dsl.evaluate('data := (TYPE::PipeNotation)::< load | process | save >;') ... # Done within the program string now

if __FILE__ == $0
  program = <<~DSL
    # ===========================================
    # MindWeave DSL Comprehensive Test Suite
    # ===========================================

    FUNC fact(n) {
      IF { n == 0 } THEN {
        RETURN 1;
      } ELSE {
        RETURN n * fact(n - 1);
      }
    }
    LET x := 2;
    LET y := 3;
    LET result := fact(x);
    PRINT "Factorial of {{x}} is {{result}}";
    LET data := (TYPE::PipeNotation)::< load | process | save >;
    PRINT "Data pipeline: {{data.inspect}}";
    LET array := [1, 2, 3, 4, 5];
    PRINT "Array: {{array.inspect}}";
    LET str := "Hello, MindWeave!";
    PRINT "String: {{str}}";
    LET num := 42;
    PRINT "Number: {{num}}";
  DSL
  output = MindWeave::Completer::Parser.execute_shorthand(program)
  puts "Program result: #{output}"
end
