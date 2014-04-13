class Parser

  GRAVITY_COEFF = {
    alpha: [1, -1.979133761292768, 0.979521463540373],
    beta:  [0.000086384997973502, 0.000172769995947004, 0.000086384997973502]
  }
  
  # Chebyshev II, Astop = 2, Fstop = 5, Fs = 100
  SMOOTHING_COEFF = {
    alpha: [1, -1.80898117793047, 0.827224480562408], 
    beta:  [0.095465967120306, -0.172688631608676, 0.095465967120306]
  }  

  FORMAT_ACCELEROMETER = 'accelerometer'
  FORMAT_GRAVITY       = 'gravity'

  attr_reader :data, :format, :parsed_data, :dot_product_data, :filtered_data

  # TODO: 
  # Should the methods be moved out of the initializer? Or, renamed to:
  # set_parsed_data, set_dot_product_data, set_filtered_data?
  def initialize(data)
    @data = data.to_s

    parse_raw_data
    dot_product_parsed_data
    filter_dot_product_data
  end

  def is_data_accelerometer?
    @format == FORMAT_ACCELEROMETER
  end

private

  # Split acceleration data into the following format:
  # [ [ [x1, x2, ..., xn],    [y1, y2, ..., yn],    [z1, z2, ..., zn] ],
  #   [ [xg1, xg2, ..., xgn], [yg1, yg2, ..., ygn], [zg1, zg2, ..., zgn] ] ]
  def split_accl_accelerometer(accl)
    @format = FORMAT_ACCELEROMETER
    
    accl = accl.flatten.collect { |i| i.split(',').collect(&:to_f) }
    split_accl = accl.transpose.collect do |total_accl|
      grav = chebyshev_filter(total_accl, GRAVITY_COEFF)
      user = total_accl.zip(grav).collect { |a, b| a - b }
      [user, grav]
    end
    split_accl.transpose
  end

  def split_accL_gravity(accl)
    @format = FORMAT_GRAVITY
    
    accl = accl.collect { |i| i.collect { |i| i.split(',').collect(&:to_f) } }
    [accl.collect {|a| a.first}.transpose, accl.collect {|a| a.last}.transpose]
  end

  # TODO:
  # You should be more explicit with your exception catching. It's better to 
  # have specific exceptions that you except to be raised, and have logic to handle those cases.
  def parse_raw_data
    accl = @data.split(';').collect { |i| i.split('|') }
    
    split_accl = if accl.first.count == 1
      split_accl_accelerometer(accl)
    else
      split_accL_gravity(accl)
    end

    user_accl, grav_accl   = split_accl
    user_x, user_y, user_z = user_accl
    grav_x, grav_y, grav_z = grav_accl
    
    @parsed_data = []
    accl.length.times do |i|
      @parsed_data << { x: user_x[i], y: user_y[i], z: user_z[i],
                        xg: grav_x[i], yg: grav_y[i], zg: grav_z[i] }
    end
  rescue
    raise 'Bad Input. Ensure data is properly formatted.'
  end

  def dot_product_parsed_data
    @dot_product_data = @parsed_data.collect do |data|
      data[:x] * data[:xg] + data[:y] * data[:yg] + data[:z] * data[:zg]
    end
  end

  def filter_dot_product_data
    @filtered_data = chebyshev_filter(@dot_product_data, SMOOTHING_COEFF)
  end

  def chebyshev_filter(input_data, coefficients)
    output_data = [0,0]
    (2..input_data.length-1).each do |i|
      output_data << coefficients[:alpha][0] * 
                      (input_data[i]    * coefficients[:beta][0] +
                       input_data[i-1]  * coefficients[:beta][1] +
                       input_data[i-2]  * coefficients[:beta][2] -
                       output_data[i-1] * coefficients[:alpha][1] -
                       output_data[i-2] * coefficients[:alpha][2])
    end
    output_data
  end

end