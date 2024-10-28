# frozen_string_literal: true

# Performs regexp replacement on a string or array of strings.
Puppet::Functions.create_function(:regsubst) do
  # @param target [String]
  #      The string or array of strings to operate on.  If an array, the replacement will be
  #      performed on each of the elements in the array, and the return value will be an array.
  # @param pattern [String, Regexp, Type[Regexp]]
  #      The regular expression matching the target string.  If you want it anchored at the start
  #      and or end of the string, you must do that with ^ and $ yourself.
  # @param replacement [String, Hash[String, String]]
  #      Replacement string. Can contain backreferences to what was matched using \\0 (whole match),
  #      \\1 (first set of parentheses), and so on.
  #      If the second argument is a Hash, and the matched text is one of its keys, the corresponding value is the replacement string.
  # @param flags [Optional[Pattern[/^[GEIM]*$/]], Pattern[/^G?$/]]
  #      Optional. String of single letter flags for how the regexp is interpreted (E, I, and M cannot be used
  #      if pattern is a precompiled regexp):
  #        - *E*         Extended regexps
  #        - *I*         Ignore case in regexps
  #        - *M*         Multiline regexps
  #        - *G*         Global replacement; all occurrences of the regexp in each target string will be replaced.  Without this, only the first occurrence will be replaced.
  # @param encoding [Enum['N','E','S','U']]
  #      Deprecated and ignored parameter, included only for compatibility.
  # @return [Array[String], String] The result of the substitution. Result type is the same as for the target parameter.
  # @deprecated
  #   This method has the optional encoding parameter, which is ignored.
  # @example Get the third octet from the node's IP address:
  #   ```puppet
  #   $i3 = regsubst($ipaddress,'^(\\d+)\\.(\\d+)\\.(\\d+)\\.(\\d+)$','\\3')
  #   ```
  dispatch :regsubst_string do
    param          'Variant[Array[Variant[String,Sensitive[String]]],Sensitive[Array[Variant[String,Sensitive[String]]]],Variant[String,Sensitive[String]]]', :target
    param          'String',                              :pattern
    param          'Variant[String,Hash[String,String]]', :replacement
    optional_param 'Optional[Pattern[/^[GEIM]*$/]]',      :flags
    optional_param "Enum['N','E','S','U']",               :encoding
  end

  # @param target [String, Array[String]]
  #      The string or array of strings to operate on.  If an array, the replacement will be
  #      performed on each of the elements in the array, and the return value will be an array.
  # @param pattern [Regexp, Type[Regexp]]
  #      The regular expression matching the target string.  If you want it anchored at the start
  #      and or end of the string, you must do that with ^ and $ yourself.
  # @param replacement [String, Hash[String, String]]
  #      Replacement string. Can contain backreferences to what was matched using \\0 (whole match),
  #      \\1 (first set of parentheses), and so on.
  #      If the second argument is a Hash, and the matched text is one of its keys, the corresponding value is the replacement string.
  # @param flags [Optional[Pattern[/^[GEIM]*$/]], Pattern[/^G?$/]]
  #      Optional. String of single letter flags for how the regexp is interpreted (E, I, and M cannot be used
  #      if pattern is a precompiled regexp):
  #        - *E*         Extended regexps
  #        - *I*         Ignore case in regexps
  #        - *M*         Multiline regexps
  #        - *G*         Global replacement; all occurrences of the regexp in each target string will be replaced.  Without this, only the first occurrence will be replaced.
  # @return [Array[String], String] The result of the substitution. Result type is the same as for the target parameter.
  # @example Put angle brackets around each octet in the node's IP address:
  #   ```puppet
  #   $x = regsubst($ipaddress, /([0-9]+)/, '<\\1>', 'G')
  #   ```
  dispatch :regsubst_regexp do
    param          'Variant[Array[Variant[String,Sensitive[String]]],Sensitive[Array[Variant[String,Sensitive[String]]]],Variant[String,Sensitive[String]]]', :target
    param          'Variant[Regexp,Type[Regexp]]',        :pattern
    param          'Variant[String,Hash[String,String]]', :replacement
    optional_param 'Pattern[/^G?$/]',                     :flags
  end

  def regsubst_string(target, pattern, replacement, flags = nil, encoding = nil)
    if encoding
      Puppet.warn_once(
        'deprecations', 'regsubst_function_encoding',
        _("The regsubst() function's encoding argument has been ignored since Ruby 1.9 and will be removed in a future release")
      )
    end

    re_flags = 0
    operation = :sub
    unless flags.nil?
      flags.split(//).each do |f|
        case f
        when 'G' then operation = :gsub
        when 'E' then re_flags |= Regexp::EXTENDED
        when 'I' then re_flags |= Regexp::IGNORECASE
        when 'M' then re_flags |= Regexp::MULTILINE
        end
      end
    end
    inner_regsubst(target, Regexp.compile(pattern, re_flags), replacement, operation)
  end

  def regsubst_regexp(target, pattern, replacement, flags = nil)
    pattern = pattern.pattern || '' if pattern.is_a?(Puppet::Pops::Types::PRegexpType)
    inner_regsubst(target, pattern, replacement, flags == 'G' ? :gsub : :sub)
  end

  def inner_regsubst(target, re, replacement, op)
    if target.is_a?(Puppet::Pops::Types::PSensitiveType::Sensitive) && target.unwrap.is_a?(Array)
      # this is a Sensitive Array
      target = target.unwrap
      target.map do |item|
        inner_regsubst(item, re, replacement, op)
      end
    elsif target.is_a?(Array)
      # this is an Array
      target.map do |item|
        inner_regsubst(item, re, replacement, op)
      end
    elsif target.is_a?(Puppet::Pops::Types::PSensitiveType::Sensitive)
      # this is a Sensitive
      target = target.unwrap
      target = target.respond_to?(op) ? target.send(op, re, replacement) : target.map { |e| e.send(op, re, replacement) }
      Puppet::Pops::Types::PSensitiveType::Sensitive.new(target)
    else
      # this should be a String
      target.respond_to?(op) ? target.send(op, re, replacement) : target.map { |e| e.send(op, re, replacement) }
    end
  end
  private :inner_regsubst
end
