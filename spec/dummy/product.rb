require 'mutant'


class MutationDuplicateAttrException < StandardError
    attr_reader :dup
    def initialize(msg='MutationDuplicateAttrException', dup=nil)
        @dup = dup
        super(msg)
    end
end

class MutationPropUndefined < StandardError
    attr_reader :prop
    def initialize(msg='MutaitonPropUndefined', prop=nil)
        @prop = prop
        super("#{msg} - #{prop}")
    end
end

class MutationValidationError < StandardError
    def initialize(msg='MutationValidationError', validator=nil)
        super("#{msg} - #{validator}")
    end
end

class Output
    attr_reader :success, :errors
    def initialize(success, errors)
        @success = success
        @errors = errors
    end

    def success?
        @success
    end
end

class Base
    
    attr_reader :output, :raise_on_error, :props, :errors, :validate_methods
    attr_writer :errors

    def self.success?
        @errors == nil || @error.length == 0
    end

    def self.run(**args)
        puts 'base.run'

        args['_mutation_props_required'] = @props
        args['_mutation_validate_methods'] = @validate_methods
        #puts args

        @output = new(args).run
    end

    def self.set_attributes(param_type, &block)
       # puts "self.set_attributes #{param_type}"
        fields = yield block
        self.props
        fields.each do |k, klass|
            #puts k, klass
            if @props.key?(k)
                raise MutationDuplicateAttrException.new(
                    msg='Mutation has recieved duplicate required attributes.', dup=k)
            else
                @props[k] = klass
            end           
        end
    end


    def self.props
        @props ||= begin
            if Base == self.superclass
                {}
            else
                self.superclass.props.dup
            end
        end
    end

    def self.validate_methods
        @validate_methods ||= begin
            if Base == self.superclass
                []
            else
                self.superclass.validate_methods.dup
            end
        end
    end

    def errors
        @errors ||= begin
            if Base == self.superclass
                []
            else
                self.superclass.errors.dup
            end
        end
    end

    def self.validate(&block)
        puts 'self.validate (&block)'
        methods = yield block
        self.validate_methods
        methods.each do |m|
            begin
                self.class.define_method(m.to_sym) do end
                self.validate_methods << m            
            rescue NoMethodError => e
                puts ("NoMethod Error - #{m} - Class: #{self.singleton_class}")
                if @raise_on_error
                    #Raise missing validator exception
                end
            end
        end
    end

    def self.required(&block)
        puts 'self.required (&block)'
        self.set_attributes('required', &block)
    end

    def self.optional(*block)
        #TODO Add to props
        # check for dups, throw mutation error
        puts 'self.required (&block)'
    end

    def initialize(args)
        puts 'initialize'
        required_args = args['_mutation_props_required'].dup
        args.delete('_mutation_props_required')
        validator_methods = args['_mutation_validate_methods'].dup
        args.delete('_mutation_validate_methods')
        
        required_args.each do |k, v|
            present = args.key?(k)       
            if !present
                 raise MutationPropUndefined.new(
                    msg='Undefined prop.  Not found in required or optional params', p)
            end
        end

        # Validate all input args against their required class/type defination
        args.each do |k, v|
            if !v.class == required_args[k]
                if raise_on_error
                    raise MutationValidationError.new(msg='Property does not match its type', validator=v)
                end
            end
        end

        puts "validator args: #{validator_methods}"
        self.errors = []
        validator_methods.each do |vm|
            puts "initialize validator_methods: #{vm}"
            begin
                self.send(vm.to_sym)
            rescue => e
                @errors << e
            end
        end

        @output = Output.new(success?, @errors)
    end

    def run
        @output
    end


    protected
    def success?
        !@errors
    end

end

class Product
    def initialize()
        @name = 'Beer'    
    end
end

class ProductCreatedMutation < Base

    required do
        {
            name: String, 
            address: String, 
            product: Product
        }
    end

    validate do 
        [:validate_name?]
    end

    def validate_name?
        puts 'I AM VALIDATE NAME'
        return name
    end

    # execute out mutation code that is
    # specific to ProductCreatedMutation
    def self.run(*args)
        super
        puts 'running mutation business logic'
        
        
        # Do other logic

        @output
    end
end


p = Product.new
output  = ProductCreatedMutation.run(product: p, name: 'Brew', address: 'hello world')
puts output.inspect