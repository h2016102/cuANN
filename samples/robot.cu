#include "../src/ann/ann.hpp"
#include "../src/kernel/kernel.hpp"
#include <iostream>
#include <fstream>
#include <boost/archive/text_oarchive.hpp>

int main ()
{
    // Instantiate the activation functor and its derivative
    // The `robot.train` data is real-valued and scaled thus we use TANH
    // and it's derivative
    cuANN::tanh_norm func;
    cuANN::tanh_norm_deriv deriv;

    // Create the Neural Network
    // It must match the input size of your data (in this case, have a look at `data/robot.train`
    // Input nodes: 48 
    // Hidden nodes: 4
    // Hidden layers: 1
    // Output nodes: 3
    //
    // In order to decide on the amount of hidden neurons, use the upper-bound rule:
    //             `# of hidden nodes = (# of training samples) / (alpha * (# of input nodes + # of output nodes)`
    //
    // where alpha = [5,10]
    // In this case, our input is 48, output is 3, samples are 374, and we use a low alpha = 5
    // Hence hidden nodes = 4.
    //
    // REMEMBER: There is no guarantee that the network will learn - it depends on weight initialisation
    //           and the training algorithm, as well as the "representative power" of the training data.
    //
    cuANN::ann net = cuANN::ann(48,4,1,3);

    // load the training data (374 samples)
    cuANN::data train_data = cuANN::data("../data/robot.train");

    // When training pass as the first two params the activation functor and it's derivative.
    // Then the training data, the Epochs for which the network will be trained,
    // the amount of CPU threads (each CPU thread "learns" a pattern)
    // the stop-error, e.g., when should the network stop learning
    // the learning rate, and the momentum rate.
    float mse = net.train(func,deriv,train_data,100000,100,4,.002,.2,.5);

    // Print back-prop MSE
    std::cout << "robot net using tanhh_norm back-prop MSE: " << mse << std::endl;

    cuANN::data test_data = cuANN::data("../data/robot.test");
    mse = net.test(func,test_data);
    std::cout << "robot network test MSE: " << mse << std::endl;
   
    // Save on disk
    std::cout << "saving network on disk" << std::endl;
    std::ofstream ofs("robot.net");
    boost::archive::text_oarchive oa(ofs);
    oa << net;
    
    return 0;
}
