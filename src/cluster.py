import numpy as np
from sklearn_extra.cluster import KMedoids

"""
    kmedoids_clustering(b, num_clusters)
    
    `x`: The matrix of data where rows correspond to observations and columns to dimensions
    `num_clusters`: Number of clusters which should be selected to represent all data
    
"""
def kmedoids_clustering(x, num_clusters):
     
    # perform clustering with KMedoids algorithm using default norm
    m = KMedoids(n_clusters= num_clusters)
    m.fit(x)
    # switch to 1-based indices
    medoid_labels = m.labels_ + 1
    medoid_indices = m.medoid_indices_ + 1
    return (medoid_labels, medoid_indices)


    

